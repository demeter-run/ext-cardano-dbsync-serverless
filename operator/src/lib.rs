use kube::Client;
use postgres::Postgres;
use prometheus::Registry;
use schemars::JsonSchema;
use serde::{Deserialize, Serialize};
use thiserror::Error;
use tracing::error;

use std::{
    fmt::Display,
    io::{self, ErrorKind},
};

#[derive(Error, Debug)]
pub enum Error {
    #[error("Postgres Error: {0}")]
    PgError(String),

    #[error("Kube Error: {0}")]
    KubeError(#[source] kube::Error),

    #[error("Finalizer Error: {0}")]
    FinalizerError(#[source] Box<kube::runtime::finalizer::Error<Error>>),

    #[error("Env Error: {0}")]
    EnvError(#[source] std::env::VarError),

    #[error("Prometheus Error: {0}")]
    PrometheusError(#[source] prometheus::Error),

    #[error("Parse Int Error: {0}")]
    ParseIntError(#[source] std::num::ParseIntError),

    #[error("Parse Float Error: {0}")]
    ParseFloatError(#[source] std::num::ParseFloatError),

    #[error("Sha256 Error: {0}")]
    Sha256Error(String),

    #[error("Bech32 Error: {0}")]
    Bech32Error(#[source] bech32::Error),
}

impl Error {
    pub fn metric_label(&self) -> String {
        format!("{self:?}").to_lowercase()
    }
}

impl From<Error> for io::Error {
    fn from(value: Error) -> Self {
        Self::new(ErrorKind::Other, value)
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
impl From<std::env::VarError> for Error {
    fn from(value: std::env::VarError) -> Self {
        Error::EnvError(value)
    }
}
impl From<prometheus::Error> for Error {
    fn from(value: prometheus::Error) -> Self {
        Error::PrometheusError(value)
    }
}
impl From<std::num::ParseIntError> for Error {
    fn from(value: std::num::ParseIntError) -> Self {
        Error::ParseIntError(value)
    }
}
impl From<std::num::ParseFloatError> for Error {
    fn from(value: std::num::ParseFloatError) -> Self {
        Error::ParseFloatError(value)
    }
}
impl From<bech32::Error> for Error {
    fn from(value: bech32::Error) -> Self {
        Error::Bech32Error(value)
    }
}

#[derive(Clone)]
pub struct State {
    registry: Registry,
    pub metrics: Metrics,
    pub pg_mainnet: Postgres,
    pub pg_preprod: Postgres,
    pub pg_preview: Postgres,
    pub kube_client: Client,
}
impl State {
    pub async fn try_new() -> Result<Self, Error> {
        let config = get_config();

        let registry = Registry::default();
        let metrics = Metrics::default().register(&registry).unwrap();

        let pg_mainnet = Postgres::new(&config.db_url_mainnet).await?;
        let pg_preprod = Postgres::new(&config.db_url_preprod).await?;
        let pg_preview = Postgres::new(&config.db_url_preview).await?;

        let kube_client = Client::try_default().await?;

        Ok(Self {
            registry,
            metrics,
            pg_mainnet,
            pg_preprod,
            pg_preview,
            kube_client,
        })
    }

    pub fn metrics_collected(&self) -> Vec<prometheus::proto::MetricFamily> {
        self.registry.gather()
    }

    pub fn get_pg_by_network(&self, network: &Network) -> Postgres {
        match network {
            Network::Mainnet => self.pg_mainnet.clone(),
            Network::Preprod => self.pg_preprod.clone(),
            Network::Preview => self.pg_preview.clone(),
        }
    }
}

#[derive(Debug, Clone, Deserialize, Serialize, JsonSchema, PartialEq, Eq, Hash)]
pub enum Network {
    #[serde(rename = "mainnet")]
    Mainnet,
    #[serde(rename = "preprod")]
    Preprod,
    #[serde(rename = "preview")]
    Preview,
}
impl Display for Network {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Network::Mainnet => write!(f, "mainnet"),
            Network::Preprod => write!(f, "preprod"),
            Network::Preview => write!(f, "preview"),
        }
    }
}

pub mod controller;
pub mod metrics;
pub mod postgres;

pub use controller::*;
pub use metrics::*;

mod config;
pub use config::*;
