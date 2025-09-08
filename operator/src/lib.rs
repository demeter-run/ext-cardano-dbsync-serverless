use kube::Client;
use postgres::Postgres;
use prometheus::Registry;
use thiserror::Error;
use tracing::error;

use std::{
    collections::HashMap,
    io::{self},
};

#[derive(Error, Debug)]
pub enum Error {
    #[error("Postgres Error: {0}")]
    PgError(String),

    #[error("Kube Error: {0}")]
    KubeError(#[source] kube::Error),

    #[error("Finalizer Error: {0}")]
    FinalizerError(#[source] Box<kube::runtime::finalizer::Error<Error>>),

    #[error("Prometheus Error: {0}")]
    PrometheusError(#[source] prometheus::Error),

    #[error("Sha256 Error: {0}")]
    Sha256Error(String),

    #[error("Bech32 Error: {0}")]
    Bech32Error(#[source] bech32::Error),

    #[error("Config Error: {0}")]
    ConfigError(String),

    #[error("Http Request error: {0}")]
    HttpError(String),
}

impl Error {
    pub fn metric_label(&self) -> String {
        format!("{self:?}").to_lowercase()
    }
}

impl From<Error> for io::Error {
    fn from(value: Error) -> Self {
        Self::other(value)
    }
}

impl From<tokio_postgres::Error> for Error {
    fn from(value: tokio_postgres::Error) -> Self {
        Error::PgError(value.to_string())
    }
}
impl From<deadpool_postgres::BuildError> for Error {
    fn from(value: deadpool_postgres::BuildError) -> Self {
        Error::PgError(value.to_string())
    }
}
impl From<deadpool_postgres::PoolError> for Error {
    fn from(value: deadpool_postgres::PoolError) -> Self {
        Error::PgError(value.to_string())
    }
}
impl From<kube::Error> for Error {
    fn from(value: kube::Error) -> Self {
        Error::KubeError(value)
    }
}
impl From<prometheus::Error> for Error {
    fn from(value: prometheus::Error) -> Self {
        Error::PrometheusError(value)
    }
}
impl From<bech32::Error> for Error {
    fn from(value: bech32::Error) -> Self {
        Error::Bech32Error(value)
    }
}
impl From<reqwest::Error> for Error {
    fn from(value: reqwest::Error) -> Self {
        Error::HttpError(value.to_string())
    }
}

#[derive(Clone)]
pub struct State {
    registry: Registry,
    pub metrics: Metrics,
    pub pg_connections: HashMap<String, Vec<Postgres>>,
    pub kube_client: Client,
}
impl State {
    pub async fn try_new() -> Result<Self, Error> {
        let config = get_config();

        let registry = Registry::default();
        let metrics = Metrics::default().register(&registry).unwrap();

        let mut pg_connections: HashMap<String, Vec<Postgres>> = HashMap::new();
        for (network, db_name) in config.db_names.iter() {
            let mut connections: Vec<Postgres> = Vec::new();
            for url in config.db_urls.iter() {
                let connection =
                    Postgres::try_new(&format!("{url}/{db_name}"), &config.db_max_connections)
                        .await?;
                connections.push(connection);
            }

            pg_connections.insert(network.clone(), connections);
        }

        let kube_client = Client::try_default().await?;

        Ok(Self {
            registry,
            metrics,
            pg_connections,
            kube_client,
        })
    }

    pub fn metrics_collected(&self) -> Vec<prometheus::proto::MetricFamily> {
        self.registry.gather()
    }

    pub fn get_pg_by_network(&self, network: &str) -> Result<&Vec<Postgres>, Error> {
        if let Some(connections) = self.pg_connections.get(network) {
            return Ok(connections);
        }

        Err(Error::ConfigError(format!(
            "postgres not configured to {network}"
        )))
    }
}

pub mod controller;
pub mod metrics;
pub mod postgres;

pub use controller::*;
pub use metrics::*;

mod config;
pub use config::*;
