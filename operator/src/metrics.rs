use futures::future;
use kube::{api::ListParams, Api, Client, Resource, ResourceExt};
use prometheus::{opts, IntCounterVec, Registry};
use std::{collections::HashMap, sync::Arc};
use tracing::{error, info, instrument};

use crate::{
    get_config,
    postgres::{Postgres, UserStatements},
    DbSyncPort, Error, State,
};

#[derive(Clone)]
pub struct Metrics {
    pub users_created: IntCounterVec,
    pub users_dropped: IntCounterVec,
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

        let users_dropped = IntCounterVec::new(
            opts!(
                "dmtr_dbsync_users_dropped_total",
                "total of users dropped in dbsync",
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
            users_dropped,
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
        registry.register(Box::new(self.users_dropped.clone()))?;
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

    pub fn count_user_created(&self, namespace: &str, network: &str) {
        let project = get_project_id(namespace);
        self.users_created
            .with_label_values(&[&project, network])
            .inc();
    }

    pub fn count_user_dropped(&self, namespace: &str, network: &str) {
        let project = get_project_id(namespace);
        self.users_dropped
            .with_label_values(&[&project, network])
            .inc();
    }

    pub fn count_dcu_consumed(&self, namespace: &str, network: &str, dcu: f64) {
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

#[instrument("metrics collector run", skip_all)]
pub async fn run_metrics_collector(state: Arc<State>) {
    tokio::spawn(async move {
        info!("collecting metrics running");

        let client = Client::try_default()
            .await
            .expect("failed to create kube client");

        let config = get_config();

        let mut metrics_state: HashMap<String, HashMap<String, UserStatements>> = HashMap::new();

        let crds_api = Api::<DbSyncPort>::all(client.clone());

        loop {
            let crds_result = crds_api.list(&ListParams::default()).await;
            if let Err(error) = crds_result {
                error!(error = error.to_string(), "error to get k8s resources");
                state.metrics.metrics_failure(&error.into());
                continue;
            }
            let crds = crds_result.unwrap();

            for crd in crds.items.iter().filter(|i| i.status.is_some()) {
                let status = crd.status.as_ref().unwrap();

                let pg_connections_result = state.get_pg_by_network(&crd.spec.network);
                if let Err(error) = pg_connections_result {
                    error!(error = error.to_string());
                    state.metrics.metrics_failure(&error);
                    continue;
                }

                let user_statements_result =
                    get_user_statements(&status.username, pg_connections_result.unwrap()).await;
                if let Err(error) = user_statements_result {
                    error!(error = error.to_string(), "error get user statements");
                    state.metrics.metrics_failure(&error);
                    continue;
                }

                let user_statements = user_statements_result.unwrap();

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

                    let dcu_per_second = config.dcu_per_second.get(&crd.spec.network);
                    if dcu_per_second.is_none() {
                        let error = Error::ConfigError(format!(
                            "dcu_per_second not configured to {} network",
                            &crd.spec.network
                        ));
                        error!(error = error.to_string());
                        state.metrics.metrics_failure(&error);
                        continue;
                    }

                    let dcu_per_second = dcu_per_second.unwrap();

                    let dcu = (total_exec_time / 1000.) * dcu_per_second;
                    state.metrics.count_dcu_consumed(
                        &crd.namespace().unwrap(),
                        &crd.spec.network,
                        dcu,
                    );
                }

                metrics_state
                    .entry(crd.spec.network.clone())
                    .and_modify(|statements| {
                        statements.insert(user_statements.usename.clone(), user_statements);
                    });
            }

            tokio::time::sleep(config.metrics_delay).await;
        }
    });
}

async fn get_user_statements(
    username: &str,
    pg_connections: &[Postgres],
) -> Result<UserStatements, Error> {
    let tasks = future::join_all(
        pg_connections
            .iter()
            .map(|pg| pg.find_metrics_by_user(username)),
    )
    .await;

    let mut user_statements_all_host = UserStatements {
        usename: username.into(),
        total_exec_time: 0.,
    };

    for user_statements_by_host_result in tasks.into_iter() {
        let user_statements_by_host = user_statements_by_host_result?;
        if user_statements_by_host.is_none() {
            continue;
        }

        let user_statements_by_host = user_statements_by_host.unwrap();
        user_statements_all_host.total_exec_time += user_statements_by_host.total_exec_time;
    }

    Ok(user_statements_all_host)
}
