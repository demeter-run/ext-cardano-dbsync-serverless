use crate::{
    postgres::{self, user_already_exists, user_create, user_disable, user_enable},
    Config, Error, Metrics, Result,
};
use futures::StreamExt;
use kube::{
    api::{Patch, PatchParams},
    runtime::{
        controller::Action,
        finalizer::{finalizer, Event},
        watcher::Config as WatcherConfig,
        Controller,
    },
    Api, Client, CustomResource, ResourceExt,
};
use rand::distributions::{Alphanumeric, DistString};
use schemars::JsonSchema;
use serde::{Deserialize, Serialize};
use serde_json::json;
use std::{sync::Arc, time::Duration};
use tracing::error;

pub static DB_SYNC_PORT_FINALIZER: &str = "dbsyncports.demeter.run";

struct Context {
    pub client: Client,
    pub metrics: Metrics,
    pub config: Config,
}
impl Context {
    pub fn new(client: Client, metrics: Metrics, config: Config) -> Self {
        Self {
            client,
            metrics,
            config,
        }
    }
}
#[derive(Clone, Default)]
pub struct State {
    registry: prometheus::Registry,
}
impl State {
    pub fn metrics(&self) -> Vec<prometheus::proto::MetricFamily> {
        self.registry.gather()
    }
}

#[derive(Debug, Clone, Deserialize, Serialize, JsonSchema)]
pub enum Network {
    #[serde(rename = "mainnet")]
    Mainnet,
    #[serde(rename = "preprod")]
    Preprod,
    #[serde(rename = "preview")]
    Preview,
}

#[derive(CustomResource, Deserialize, Serialize, Clone, Debug, JsonSchema)]
#[kube(kind = "DbSyncPort", group = "demeter.run", version = "v1", namespaced)]
#[kube(status = "DbSyncPortStatus")]
pub struct DbSyncPortSpec {
    pub network: Network,
}
#[derive(Deserialize, Serialize, Clone, Default, Debug, JsonSchema)]
pub struct DbSyncPortStatus {
    pub username: String,
    pub password: String,
}
impl DbSyncPort {
    fn was_executed(&self) -> bool {
        self.status
            .as_ref()
            .map(|s| !s.username.is_empty())
            .unwrap_or(false)
    }

    async fn reconcile(
        &self,
        ctx: Arc<Context>,
        pg_client: &mut tokio_postgres::Client,
    ) -> Result<Action> {
        let client = ctx.client.clone();
        let ns = self.namespace().unwrap();
        let name = self.name_any();
        let crds: Api<DbSyncPort> = Api::namespaced(client, &ns);

        let username = format!("{name}.{ns}");
        let password = Alphanumeric.sample_string(&mut rand::thread_rng(), 16);

        if !self.was_executed() {
            match user_already_exists(pg_client, &username).await? {
                true => user_enable(pg_client, &username, &password).await?,
                false => user_create(pg_client, &username, &password).await?,
            };

            let new_status = Patch::Apply(json!({
                "apiVersion": "demeter.run/v1",
                "kind": "DbSyncPort",
                "status": DbSyncPortStatus {
                    username: username.clone(),
                    password: password.clone()
                }
            }));

            let ps = PatchParams::apply("cntrlr").force();
            crds.patch_status(&name, &ps, &new_status)
                .await
                .map_err(Error::KubeError)?;

            ctx.metrics.count_user_created(&username);
        };

        Ok(Action::requeue(Duration::from_secs(5 * 60)))
    }

    async fn cleanup(
        &self,
        ctx: Arc<Context>,
        pg_client: &mut tokio_postgres::Client,
    ) -> Result<Action> {
        let username = self.status.as_ref().unwrap().username.clone();
        user_disable(pg_client, &username).await?;
        ctx.metrics.count_user_deactivated(&username);
        Ok(Action::await_change())
    }
}

async fn reconcile(crd: Arc<DbSyncPort>, ctx: Arc<Context>) -> Result<Action> {
    let url = match crd.spec.network {
        Network::Mainnet => &ctx.config.db_url_mainnet,
        Network::Preprod => &ctx.config.db_url_preprod,
        Network::Preview => &ctx.config.db_url_preview,
    };

    let ns = crd.namespace().unwrap();
    let crds: Api<DbSyncPort> = Api::namespaced(ctx.client.clone(), &ns);

    let mut pg_client = postgres::connect(url).await?;

    finalizer(&crds, DB_SYNC_PORT_FINALIZER, crd, |event| async {
        match event {
            Event::Apply(crd) => crd.reconcile(ctx.clone(), &mut pg_client).await,
            Event::Cleanup(crd) => crd.cleanup(ctx.clone(), &mut pg_client).await,
        }
    })
    .await
    .map_err(|e| Error::FinalizerError(Box::new(e)))
}

fn error_policy(crd: Arc<DbSyncPort>, err: &Error, ctx: Arc<Context>) -> Action {
    error!("reconcile failed: {:?}", err);
    ctx.metrics.reconcile_failure(&crd, err);
    Action::requeue(Duration::from_secs(5))
}

pub async fn run(state: State, config: Config) -> Result<(), Error> {
    let client = Client::try_default().await?;
    let crds = Api::<DbSyncPort>::all(client.clone());
    let metrics = Metrics::default().register(&state.registry).unwrap();
    let ctx = Context::new(client, metrics, config);

    Controller::new(crds, WatcherConfig::default().any_semantic())
        .shutdown_on_signal()
        .run(reconcile, error_policy, Arc::new(ctx))
        .for_each(|_| futures::future::ready(()))
        .await;

    Ok(())
}
