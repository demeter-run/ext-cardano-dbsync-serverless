use std::time::Duration;

use prometheus::Registry;
use thiserror::Error;

#[derive(Error, Debug)]
pub enum Error {
    #[error("Postgres Error: {0}")]
    PgError(#[source] tokio_postgres::Error),

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
}

impl Error {
    pub fn metric_label(&self) -> String {
        format!("{self:?}").to_lowercase()
    }
}
impl From<tokio_postgres::Error> for Error {
    fn from(value: tokio_postgres::Error) -> Self {
        Error::PgError(value)
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

#[derive(Clone, Default)]
pub struct State {
    registry: Registry,
    pub metrics: Metrics,
}
impl State {
    pub fn new() -> Self {
        let registry = Registry::default();
        let metrics = Metrics::default().register(&registry).unwrap();
        Self { registry, metrics }
    }

    pub fn metrics_collected(&self) -> Vec<prometheus::proto::MetricFamily> {
        self.registry.gather()
    }
}

#[derive(Clone)]
pub struct Config {
    pub db_url_mainnet: String,
    pub db_url_preprod: String,
    pub db_url_preview: String,
    pub metrics_delay: Duration,
    pub dcu_base: u64,
}
impl Config {
    pub fn try_new() -> Result<Self, Error> {
        let db_url_mainnet = std::env::var("DB_URL_MAINNET")?;
        let db_url_preprod = std::env::var("DB_URL_PREPROD")?;
        let db_url_preview = std::env::var("DB_URL_PREVIEW")?;
        let metrics_delay = Duration::from_secs(std::env::var("METRICS_DELAY")?.parse::<u64>()?);
        let dcu_base = std::env::var("DCU_BASE")?.parse::<u64>()?;

        Ok(Self {
            db_url_mainnet,
            db_url_preprod,
            db_url_preview,
            metrics_delay,
            dcu_base,
        })
    }
}

pub mod controller;
pub mod metrics;
pub mod postgres;

pub use controller::*;
pub use metrics::*;
