use bech32::ToBase32;
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
use sha3::{Digest, Sha3_256};
use std::{sync::Arc, time::Duration};
use tracing::error;

use crate::{postgres::Postgres, Config, Error, Metrics, Network, State};

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

#[derive(CustomResource, Deserialize, Serialize, Clone, Debug, JsonSchema)]
#[kube(
    kind = "DbSyncPort",
    group = "demeter.run",
    version = "v1alpha1",
    namespaced
)]
#[kube(status = "DbSyncPortStatus")]
#[kube(printcolumn = r#"
        {"name": "Network", "jsonPath": ".spec.network", "type": "string"},
        {"name": "Username", "jsonPath": ".status.username",  "type": "string"},
        {"name": "Password", "jsonPath": ".status.password", "type": "string"}
    "#)]
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

    async fn reconcile(&self, ctx: Arc<Context>, pg: &mut Postgres) -> Result<Action, Error> {
        let client = ctx.client.clone();
        let ns = self.namespace().unwrap();
        let name = self.name_any();
        let crds: Api<DbSyncPort> = Api::namespaced(client, &ns);

        let username = gen_username_hash(&format!("{name}.{ns}")).await?;
        let password = Alphanumeric.sample_string(&mut rand::thread_rng(), 16);

        if !self.was_executed() {
            pg.create_user(&username, &password).await?;

            let status = Patch::Apply(json!({
                "apiVersion": "demeter.run/v1alpha1",
                "kind": "DbSyncPort",
                "status": DbSyncPortStatus {
                    username: username.clone(),
                    password: password.clone()
                }
            }));

            let ps = PatchParams::apply("cntrlr").force();
            crds.patch_status(&name, &ps, &status)
                .await
                .map_err(Error::KubeError)?;

            ctx.metrics.count_user_created(&username);
        };

        Ok(Action::await_change())
    }

    async fn cleanup(&self, ctx: Arc<Context>, pg: &mut Postgres) -> Result<Action, Error> {
        if self.was_executed() {
            let username = self.status.as_ref().unwrap().username.clone();
            pg.drop_user(&username).await?;
            ctx.metrics.count_user_deactivated(&username);
        }

        Ok(Action::await_change())
    }
}

async fn reconcile(crd: Arc<DbSyncPort>, ctx: Arc<Context>) -> Result<Action, Error> {
    let url = match crd.spec.network {
        Network::Mainnet => &ctx.config.db_url_mainnet,
        Network::Preprod => &ctx.config.db_url_preprod,
        Network::Preview => &ctx.config.db_url_preview,
    };

    let ns = crd.namespace().unwrap();
    let crds: Api<DbSyncPort> = Api::namespaced(ctx.client.clone(), &ns);

    let mut postgres = Postgres::new(url).await?;

    finalizer(&crds, DB_SYNC_PORT_FINALIZER, crd, |event| async {
        match event {
            Event::Apply(crd) => crd.reconcile(ctx.clone(), &mut postgres).await,
            Event::Cleanup(crd) => crd.cleanup(ctx.clone(), &mut postgres).await,
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

async fn gen_username_hash(username: &str) -> Result<String, Error> {
    let mut hasher = Sha3_256::new();
    hasher.update(username);
    let sha256_hash = hasher.finalize();

    let bech32_hash = bech32::encode(
        "dmtr_dbsync",
        sha256_hash.to_base32(),
        bech32::Variant::Bech32,
    )?;

    Ok(bech32_hash)
}

pub async fn run(state: Arc<State>, config: Config) -> Result<(), Error> {
    let client = Client::try_default().await?;
    let crds = Api::<DbSyncPort>::all(client.clone());

    let ctx = Context::new(client, state.metrics.clone(), config);

    Controller::new(crds, WatcherConfig::default().any_semantic())
        .shutdown_on_signal()
        .run(reconcile, error_policy, Arc::new(ctx))
        .for_each(|_| futures::future::ready(()))
        .await;

    Ok(())
}
