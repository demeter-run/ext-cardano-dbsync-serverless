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
    pub query_timeout: u64,
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

        let query_timeout = match env::var("QUERY_TIMEOUT") {
            Ok(val) => val.parse::<u64>().expect("QUERY_TIMEOUT must be a number"),
            Err(_) => 12000,
        };

        Self {
            db_urls,
            db_names,
            dcu_per_second,
            metrics_delay,
            query_timeout,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_from_env() {
        env::set_var("DB_URLS", "url1,url2");
        env::set_var(
            "DB_NAMES",
            "preview=dbsync-preview,preprod=dbsync-preprod,mainnet=dbsync-mainnet",
        );
        env::set_var("DCU_PER_SECOND", "preview=5,preprod=5,mainnet=5");
        env::set_var("METRICS_DELAY", "100");
        env::set_var("QUERY_TIMEOUT", "100");

        let config = Config::from_env();
        assert_eq!(config.db_urls, vec!["url1".to_owned(), "url2".to_owned()]);
        assert_eq!(
            config.db_names,
            HashMap::from([
                ("preview".to_owned(), "dbsync-preview".to_owned()),
                ("preprod".to_owned(), "dbsync-preprod".to_owned()),
                ("mainnet".to_owned(), "dbsync-mainnet".to_owned())
            ])
        );
        assert_eq!(
            config.dcu_per_second,
            HashMap::from([
                ("preview".to_owned(), 5.0),
                ("preprod".to_owned(), 5.0),
                ("mainnet".to_owned(), 5.0)
            ])
        );
        assert_eq!(config.query_timeout, 100);

        // Check default query timeout
        env::remove_var("QUERY_TIMEOUT");
        let config = Config::from_env();
        assert_eq!(config.query_timeout, 12000);
    }
}
