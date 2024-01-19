use lazy_static::lazy_static;
use std::{collections::HashMap, env, time::Duration};

lazy_static! {
    static ref CONTROLLER_CONFIG: Config = Config::from_env();
}

pub fn get_config() -> &'static Config {
    &CONTROLLER_CONFIG
}

#[derive(Debug, Clone)]
pub struct Config {
    pub db_urls: Vec<String>,
    pub db_names: HashMap<String, String>,
    pub dcu_per_second: HashMap<String, f64>,

    pub metrics_delay: Duration,
}

impl Config {
    pub fn from_env() -> Self {
        let db_urls = env::var("DB_URLS")
            .expect("DB_URLS must be set")
            .split(',')
            .map(|s| s.into())
            .collect();

        let db_names = env::var("DB_NAMES")
            .expect("DB_NAMES must be set")
            .split(',')
            .map(|pair| {
                let parts: Vec<&str> = pair.split('=').collect();
                (parts[0].into(), parts[1].into())
            })
            .collect();

        let dcu_per_second = env::var("DCU_PER_SECOND")
            .expect("DCU_PER_SECOND must be set")
            .split(',')
            .map(|pair| {
                let parts: Vec<&str> = pair.split('=').collect();
                let dcu = parts[1]
                    .parse::<f64>()
                    .expect("DCU_PER_SECOND must be NETWORK=NUMBER");

                (parts[0].into(), dcu)
            })
            .collect();

        let metrics_delay = Duration::from_secs(
            env::var("METRICS_DELAY")
                .expect("METRICS_DELAY must be set")
                .parse::<u64>()
                .expect("METRICS_DELAY must be a number"),
        );

        Self {
            db_urls,
            db_names,
            dcu_per_second,
            metrics_delay,
        }
    }
}
