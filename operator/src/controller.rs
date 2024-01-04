use bech32::ToBase32;
use futures::StreamExt;
use kube::{
    api::{ListParams, Patch, PatchParams},
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
use tracing::{error, info, instrument};

use crate::{postgres::Postgres, Error, Network, State};

pub static DB_SYNC_PORT_FINALIZER: &str = "dbsyncports.demeter.run";

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

    async fn reconcile(&self, state: Arc<State>, pg: &Postgres) -> Result<Action, Error> {
        let client = state.kube_client.clone();
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

            info!({ username }, "user created");
            state.metrics.count_user_created(&ns, &self.spec.network);
        };

        Ok(Action::await_change())
    }

    async fn cleanup(&self, state: Arc<State>, pg: &Postgres) -> Result<Action, Error> {
        if self.was_executed() {
            let ns = self.namespace().unwrap();
            let username = self.status.as_ref().unwrap().username.clone();
            pg.drop_user(&username).await?;

            info!({ username }, "user dropped");
            state.metrics.count_user_dropped(&ns, &self.spec.network);
        }

        Ok(Action::await_change())
    }
}

async fn reconcile(crd: Arc<DbSyncPort>, state: Arc<State>) -> Result<Action, Error> {
    let ns = crd.namespace().unwrap();
    let crds: Api<DbSyncPort> = Api::namespaced(state.kube_client.clone(), &ns);

    let postgres = state.get_pg_by_network(&crd.spec.network);

    finalizer(&crds, DB_SYNC_PORT_FINALIZER, crd, |event| async {
        match event {
            Event::Apply(crd) => crd.reconcile(state.clone(), &postgres).await,
            Event::Cleanup(crd) => crd.cleanup(state.clone(), &postgres).await,
        }
    })
    .await
    .map_err(|e| Error::FinalizerError(Box::new(e)))
}

fn error_policy(crd: Arc<DbSyncPort>, error: &Error, state: Arc<State>) -> Action {
    error!(error = error.to_string(), "reconcile failed");
    state.metrics.reconcile_failure(&crd, error);
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

    let bech32_truncated: String = bech32_hash.chars().take(32).collect();

    Ok(bech32_truncated)
}

#[instrument("controller run", skip_all)]
pub async fn run(state: Arc<State>) {
    info!("listening crds running");

    let client = Client::try_default()
        .await
        .expect("failed to create kube client");

    let crds = Api::<DbSyncPort>::all(client.clone());
    if let Err(e) = crds.list(&ListParams::default().limit(1)).await {
        error!("CRD is not queryable; {e:?}. Is the CRD installed?");
        std::process::exit(1);
    }

    Controller::new(crds, WatcherConfig::default().any_semantic())
        .shutdown_on_signal()
        .run(reconcile, error_policy, state)
        .filter_map(|x| async move { std::result::Result::ok(x) })
        .for_each(|_| futures::future::ready(()))
        .await;
}
