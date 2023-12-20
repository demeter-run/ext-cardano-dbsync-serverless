use kube::{Resource, ResourceExt};
use prometheus::{opts, IntCounterVec, Registry};
use std::{sync::Arc, thread::sleep};
use tracing::error;

use crate::{
    postgres::{Postgres, UserStatements},
    Config, DbSyncPort, Error, Network, State,
};

#[derive(Clone)]
pub struct Metrics {
    pub users_created: IntCounterVec,
    pub users_deactivated: IntCounterVec,
    pub reconcile_failures: IntCounterVec,
    pub metrics_failures: IntCounterVec,
    pub dcu: IntCounterVec,
}

impl Default for Metrics {
    fn default() -> Self {
        let users_created = IntCounterVec::new(
            opts!(
                "crd_controller_users_created_total",
                "total of users created in dbsync",
            ),
            &["username"],
        )
        .unwrap();

        let users_deactivated = IntCounterVec::new(
            opts!(
                "crd_controller_users_deactivated_total",
                "total of users deactivated in dbsync",
            ),
            &["username"],
        )
        .unwrap();

        let reconcile_failures = IntCounterVec::new(
            opts!(
                "crd_controller_reconciliation_errors_total",
                "reconciliation errors",
            ),
            &["instance", "error"],
        )
        .unwrap();

        let metrics_failures = IntCounterVec::new(
            opts!(
                "metrics_controller_errors_total",
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
            users_deactivated,
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
        registry.register(Box::new(self.users_deactivated.clone()))?;
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

    pub fn count_user_created(&self, username: &str) {
        self.users_created.with_label_values(&[username]).inc();
    }

    pub fn count_user_deactivated(&self, username: &str) {
        self.users_deactivated.with_label_values(&[username]).inc();
    }

    pub fn count_dcu_consumed(&self, usename: &str, network: &Network, dcu: f64) {
        let project = usename.split_once("prj-").unwrap().1;
        let service = format!("{}-{}", DbSyncPort::kind(&()), network);
        let service_type = format!("{}.{}", DbSyncPort::plural(&()), DbSyncPort::group(&()));
        let tenancy = "proxy";

        let dcu: u64 = dcu.ceil() as u64;

        self.dcu
            .with_label_values(&[project, &service, &service_type, tenancy])
            .inc_by(dcu);
    }
}

pub async fn run_metrics_collector(state: Arc<State>, config: Config) -> Result<(), Error> {
    let mut network_state: Vec<(Network, String, f64, Option<Vec<UserStatements>>)> = vec![
        (
            Network::Mainnet,
            config.db_url_mainnet,
            config.dcu_per_second_mainnet,
            None,
        ),
        (
            Network::Preprod,
            config.db_url_preprod,
            config.dcu_per_second_preprod,
            None,
        ),
        (
            Network::Preview,
            config.db_url_preview,
            config.dcu_per_second_preview,
            None,
        ),
    ];

    loop {
        for (network, url, dcu_per_second, latest_execution) in network_state.iter_mut() {
            let postgres_result = Postgres::new(url).await;
            if let Err(err) = postgres_result {
                error!("Error to connect postgres: {err}");
                state.metrics.metrics_failure(&err);
                continue;
            }
            let postgres = postgres_result.unwrap();

            let user_statements_result = postgres.user_metrics().await;
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

            if let Some(latest_execution) = latest_execution {
                for user_statement in user_statements.iter() {
                    let latest_user_statement = latest_execution
                        .iter()
                        .find(|le| le.usename.eq(&user_statement.usename));

                    let mut total_exec_time = user_statement.total_exec_time;

                    if let Some(latest_user_statement) = latest_user_statement {
                        total_exec_time =
                            user_statement.total_exec_time - latest_user_statement.total_exec_time;
                    }

                    if total_exec_time == 0.0 {
                        continue;
                    }

                    let dcu = (total_exec_time / 1000.) * dcu_per_second as &f64;
                    state
                        .metrics
                        .count_dcu_consumed(&user_statement.usename, network, dcu);
                }
            }

            *latest_execution = Some(user_statements);
        }

        sleep(config.metrics_delay)
    }
}
