use kube::ResourceExt;
use prometheus::{opts, IntCounterVec, Registry};
use std::{sync::Arc, thread::sleep};
use tracing::error;

use crate::{
    postgres::Postgres,
    Config, DbSyncPort, Error, State,
};

#[derive(Clone)]
pub struct Metrics {
    pub users_created: IntCounterVec,
    pub users_deactivated: IntCounterVec,
    pub failures: IntCounterVec,
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

        let failures = IntCounterVec::new(
            opts!(
                "crd_controller_reconciliation_errors_total",
                "reconciliation errors",
            ),
            &["instance", "error"],
        )
        .unwrap();

        Metrics {
            users_created,
            users_deactivated,
            failures,
        }
    }
}

impl Metrics {
    pub fn register(self, registry: &Registry) -> Result<Self, prometheus::Error> {
        registry.register(Box::new(self.failures.clone()))?;
        registry.register(Box::new(self.users_created.clone()))?;
        registry.register(Box::new(self.users_deactivated.clone()))?;
        Ok(self)
    }

    pub fn reconcile_failure(&self, crd: &DbSyncPort, e: &Error) {
        self.failures
            .with_label_values(&[crd.name_any().as_ref(), e.metric_label().as_ref()])
            .inc()
    }

    pub fn count_user_created(&self, username: &str) {
        self.users_created.with_label_values(&[username]).inc();
    }

    pub fn count_user_deactivated(&self, username: &str) {
        self.users_deactivated.with_label_values(&[username]).inc();
    }
}

pub async fn run_metrics_collector(state: Arc<State>, config: Config) -> Result<(), Error> {
    let db_urls = &vec![
        config.db_url_mainnet,
        config.db_url_preprod,
        config.db_url_preview,
    ];

    loop {
        for url in db_urls {
            let postgres_result = Postgres::new(url).await;
            if let Err(err) = postgres_result {
                error!("Error to connect postgres: {err}");
                continue;
            }
            let postgres = postgres_result.unwrap();

            let user_statements_result = postgres.user_metrics().await;
            if let Err(err) = user_statements_result {
                error!("Error get user statements: {err}");
                continue;
            }

            let user_statements = user_statements_result.unwrap();
            if user_statements.is_none() {
                continue;
            }

            let user_statements = user_statements.unwrap();
            
            // TODO: calculate dcu
        }

        sleep(config.metrics_delay)
    }
}
