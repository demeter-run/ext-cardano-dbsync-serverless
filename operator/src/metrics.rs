use kube::{api::ListParams, Api, Client, Resource, ResourceExt};
use prometheus::{opts, IntCounterVec, Registry};
use std::{collections::HashMap, sync::Arc, thread::sleep};
use tracing::error;

use crate::{get_config, postgres::UserStatements, DbSyncPort, Error, Network, State};

#[derive(Clone)]
pub struct Metrics {
    pub users_created: IntCounterVec,
    pub users_droped: IntCounterVec,
    pub reconcile_failures: IntCounterVec,
    pub metrics_failures: IntCounterVec,
    pub dcu: IntCounterVec,
}

impl Default for Metrics {
    fn default() -> Self {
        let users_created = IntCounterVec::new(
            opts!(
                "dmtr_dbsync_users_created_total",
                "total of users created in dbsync",
            ),
            &["project", "network"],
        )
        .unwrap();

        let users_droped = IntCounterVec::new(
            opts!(
                "dmtr_dbsync_users_droped_total",
                "total of users deactivated in dbsync",
            ),
            &["project", "network"],
        )
        .unwrap();

        let reconcile_failures = IntCounterVec::new(
            opts!(
                "dmtr_dbsync_reconciliation_errors_total",
                "reconciliation errors",
            ),
            &["instance", "error"],
        )
        .unwrap();

        let metrics_failures = IntCounterVec::new(
            opts!(
                "dmtr_dbsync_metrics_errors_total",
                "errors to calculation metrics",
            ),
            &["error"],
        )
        .unwrap();

        let dcu = IntCounterVec::new(
            opts!("dmtr_consumed_dcus", "quantity of dcu consumed",),
            &["project", "service", "service_type", "tenancy"],
        )
        .unwrap();

        Metrics {
            users_created,
            users_droped,
            reconcile_failures,
            metrics_failures,
            dcu,
        }
    }
}

impl Metrics {
    pub fn register(self, registry: &Registry) -> Result<Self, prometheus::Error> {
        registry.register(Box::new(self.reconcile_failures.clone()))?;
        registry.register(Box::new(self.users_created.clone()))?;
        registry.register(Box::new(self.users_droped.clone()))?;
        registry.register(Box::new(self.dcu.clone()))?;
        Ok(self)
    }

    pub fn reconcile_failure(&self, crd: &DbSyncPort, e: &Error) {
        self.reconcile_failures
            .with_label_values(&[crd.name_any().as_ref(), e.metric_label().as_ref()])
            .inc()
    }

    pub fn metrics_failure(&self, e: &Error) {
        self.metrics_failures
            .with_label_values(&[e.metric_label().as_ref()])
            .inc()
    }

    pub fn count_user_created(&self, namespace: &str, network: &Network) {
        let project = get_project_id(namespace);
        self.users_created
            .with_label_values(&[&project, &network.to_string()])
            .inc();
    }

    pub fn count_user_deactivated(&self, namespace: &str, network: &Network) {
        let project = get_project_id(namespace);
        self.users_droped
            .with_label_values(&[&project, &network.to_string()])
            .inc();
    }

    pub fn count_dcu_consumed(&self, namespace: &str, network: &Network, dcu: f64) {
        let project = get_project_id(namespace);
        let service = format!("{}-{}", DbSyncPort::kind(&()), network);
        let service_type = format!("{}.{}", DbSyncPort::plural(&()), DbSyncPort::group(&()));
        let tenancy = "proxy";

        let dcu: u64 = dcu.ceil() as u64;

        self.dcu
            .with_label_values(&[&project, &service, &service_type, tenancy])
            .inc_by(dcu);
    }
}

fn get_project_id(namespace: &str) -> String {
    namespace.split_once("prj-").unwrap().1.into()
}

pub async fn run_metrics_collector(state: Arc<State>) -> Result<(), Error> {
    let client = Client::try_default().await?;
    let config = get_config();

    let mut metrics_state: HashMap<Network, HashMap<String, UserStatements>> = HashMap::new();

    loop {
        let crds_api = Api::<DbSyncPort>::all(client.clone());
        let crds_result = crds_api.list(&ListParams::default()).await;
        if let Err(err) = crds_result {
            error!("Error to get k8s resources: {err}");
            state.metrics.metrics_failure(&err.into());
            continue;
        }
        let crds = crds_result.unwrap();

        for crd in crds.items.iter().filter(|i| i.status.is_some()) {
            let status = crd.status.as_ref().unwrap();

            let postgres = state.get_pg_by_network(&crd.spec.network);

            let user_statements_result = postgres.find_metrics_by_user(&status.username).await;
            if let Err(err) = user_statements_result {
                error!("Error get user statements: {err}");
                state.metrics.metrics_failure(&err);
                continue;
            }

            let user_statements = user_statements_result.unwrap();
            if user_statements.is_none() {
                continue;
            }

            let user_statements = user_statements.unwrap();

            let latest_user_statement = metrics_state
                .entry(crd.spec.network.clone())
                .or_default()
                .get(&user_statements.usename);

            if let Some(latest_user_statement) = latest_user_statement {
                let total_exec_time =
                    user_statements.total_exec_time - latest_user_statement.total_exec_time;

                if total_exec_time == 0.0 {
                    continue;
                }

                let dcu_per_second = match &crd.spec.network {
                    Network::Mainnet => config.dcu_per_second_mainnet,
                    Network::Preprod => config.dcu_per_second_preprod,
                    Network::Preview => config.dcu_per_second_preview,
                };

                let dcu = (total_exec_time / 1000.) * dcu_per_second;
                state
                    .metrics
                    .count_dcu_consumed(&crd.namespace().unwrap(), &crd.spec.network, dcu);
            }

            metrics_state
                .entry(crd.spec.network.clone())
                .and_modify(|statements| {
                    statements.insert(user_statements.usename.clone(), user_statements);
                });
        }

        sleep(config.metrics_delay)
    }
}
