use lazy_static::lazy_static;
use std::{env, time::Duration};

lazy_static! {
    static ref CONTROLLER_CONFIG: Config = Config::from_env();
}

pub fn get_config() -> &'static Config {
    &CONTROLLER_CONFIG
}

#[derive(Debug, Clone)]
pub struct Config {
    pub db_url_mainnet: String,
    pub db_url_preprod: String,
    pub db_url_preview: String,

    pub dcu_per_second_mainnet: f64,
    pub dcu_per_second_preprod: f64,
    pub dcu_per_second_preview: f64,

    pub metrics_delay: Duration,
}

impl Config {
    pub fn from_env() -> Self {
        let db_url_mainnet = env::var("DB_URL_MAINNET").expect("DB_URL_MAINNET must be set");
        let db_url_preprod = env::var("DB_URL_PREPROD").expect("DB_URL_PREPROD must be set");
        let db_url_preview = env::var("DB_URL_PREVIEW").expect("DB_URL_PREVIEW must be set");

        let metrics_delay = Duration::from_secs(
            env::var("METRICS_DELAY")
                .expect("METRICS_DELAY must be set")
                .parse::<u64>()
                .expect("METRICS_DELAY must be a number"),
        );

        let dcu_per_second_mainnet = env::var("DCU_PER_SECOND_MAINNET")
            .expect("DCU_PER_SECOND_MAINNET must be set")
            .parse::<f64>()
            .expect("DCU_PER_SECOND_MAINNET must be a number");
        let dcu_per_second_preprod = env::var("DCU_PER_SECOND_PREPROD")
            .expect("DCU_PER_SECOND_PREPROD must be set")
            .parse::<f64>()
            .expect("DCU_PER_SECOND_PREPROD must be a number");
        let dcu_per_second_preview = env::var("DCU_PER_SECOND_PREVIEW")
            .expect("DCU_PER_SECOND_PREVIEW must be set")
            .parse::<f64>()
            .expect("DCU_PER_SECOND_PREVIEW must be a number");

        Self {
            db_url_mainnet,
            db_url_preprod,
            db_url_preview,
            metrics_delay,
            dcu_per_second_mainnet,
            dcu_per_second_preprod,
            dcu_per_second_preview,
        }
    }
}
