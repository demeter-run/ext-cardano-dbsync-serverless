use thiserror::Error;

#[derive(Error, Debug)]
pub enum Error {
    #[error("Postgres Error: {0}")]
    PgError(#[source] tokio_postgres::Error),

    #[error("Kube Error: {0}")]
    KubeError(#[source] kube::Error),

    #[error("Finalizer Error: {0}")]
    FinalizerError(#[source] Box<kube::runtime::finalizer::Error<Error>>),
}

impl Error {
    pub fn metric_label(&self) -> String {
        format!("{self:?}").to_lowercase()
    }
}

pub type Result<T, E = Error> = std::result::Result<T, E>;

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

pub struct Config {
    pub db_url_mainnet: String,
    pub db_url_preprod: String,
    pub db_url_preview: String,
}
impl Config {
    pub fn new() -> Self {
        Self {
            db_url_mainnet: std::env::var("DB_URL_MAINNET").expect("DB_URL_MAINNET must be set"),
            db_url_preprod: std::env::var("DB_URL_PREPROD").expect("DB_URL_PREPROD must be set"),
            db_url_preview: std::env::var("DB_URL_PREVIEW").expect("DB_URL_PREVIEW must be set"),
        }
    }
}

pub mod controller;
pub mod postgres;
pub use crate::controller::*;

mod metrics;
pub use metrics::Metrics;
