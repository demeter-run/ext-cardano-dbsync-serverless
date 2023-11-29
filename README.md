# Ext Cardano DB Sync

This project is a Kubernetes custom controller to create users on dbsync's Postgres. This controller defines a new CRD DbSyncPort on Kubernetes and when the new users enable the External Dbsync, the Demiter will generate a manifest with the kind DbSyncPort and the controller will be watching for creating a new user on Postgres.

## Environment

| Key            | Value                                 |
| -------------- | ------------------------------------- |
| ADDR           | 0.0.0.0:5000                          |
| DB_URL_MAINNET | postgres://user:password@host:post/db |
| DB_URL_PREPROD | postgres://user:password@host:post/db |
| DB_URL_PREVIEW | postgres://user:password@host:post/db |

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
