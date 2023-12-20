# Ext Cardano DB Sync

This project is a Kubernetes custom controller to create users on dbsync's Postgres. This controller defines a new CRD DbSyncPort on Kubernetes and when the new users enable the External Dbsync, the Demiter will generate a manifest with the kind DbSyncPort and the controller will be watching for creating a new user on Postgres.

> [!IMPORTANT]  
> The metrics collector uses the `pg_stat_statements` extension enabled on Postgres. To enable that extension follow the steps bellow.

- set pg_stat_statements at `shared_preload_libraries` on postgresql.conf
  ```
  shared_preload_libraries = 'pg_stat_statements'
  ```
- create the extension on postgres
  ```
  CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
  ```

## Environment

| Key                    | Value                                 |
| ---------------------- | ------------------------------------- |
| ADDR                   | 0.0.0.0:5000                          |
| DB_URL_MAINNET         | postgres://user:password@host:post/db |
| DB_URL_PREPROD         | postgres://user:password@host:post/db |
| DB_URL_PREVIEW         | postgres://user:password@host:post/db |
| METRICS_DELAY          | 30                                    |
| DCU_PER_SECOND_MAINNET | 10                                    |
| DCU_PER_SECOND_PREPROD | 10                                    |
| DCU_PER_SECOND_PREVIEW | 10                                    |

## Commands

To generate the CRD will need to execute crdgen

```bash
cargo run --bin=crdgen
```

and execute the controller

```bash
cargo run
```

## Metrics

to collect metrics for Prometheus, an http api will enable with the route /metrics.

```
/metrics
```
