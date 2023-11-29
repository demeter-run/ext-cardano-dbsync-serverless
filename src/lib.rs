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

pub mod controller;
pub mod postgres;
pub use crate::controller::*;

mod metrics;
pub use metrics::Metrics;
