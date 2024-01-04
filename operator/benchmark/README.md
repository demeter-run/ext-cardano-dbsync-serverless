# Benchmark

This folder has a configuration to run benchmarks on Postgres dbsync. Docker is used to access the tool pgbench and bench.sql is some common queries.

## Compile docker image

To use the image is necessary to compile

```bash
docker build -t pgbench .
```

## Environment

The pgbench needs some environment variables to work, then create a file `.env` and set these envs below

| Key        | Value |
| ---------- | ----- |
| PGDATABASE |       |
| PGHOST     |       |
| PGPORT     |       |
| PGUSER     |       |
| PGPASSWORD |       |

## Run benchmark

To run the benchmark it's necessary to run the docker image compiled before, but it's necessary to use some parameters of pgbench.

```bash
docker run --env-file .env --network host --volume ./bench.sql:/bench.sql pgbench:latest -c 10 -T 5 -n -f /bench.sql
```

- `-c` concurrences users
- `-T` execution time(seconds)
- `-t` number of transactions each client runs. Default is 10.
- `-j` number of worker threads
- `-n` enable for the custom scripts
- `-f` script path

more parameters
https://www.postgresql.org/docs/devel/pgbench.html

### Metrics example 

The return when the command is finished

```
transaction type: /bench.sql
scaling factor: 1
query mode: simple
number of clients: 4
number of threads: 1
maximum number of tries: 1
duration: 10 s
number of transactions actually processed: 16
number of failed transactions: 0 (0.000%)
latency average = 1562.050 ms
initial connection time = 3951.848 ms
tps = 2.560738 (without initial connection time)
```