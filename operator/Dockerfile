FROM rust:1.89.0-slim-bookworm AS build

WORKDIR /app

RUN apt update
RUN apt install -y build-essential pkg-config libssl-dev cmake

COPY ./Cargo.toml ./Cargo.toml
COPY ./src ./src

RUN cargo build --release

FROM debian:stable-slim

COPY --from=build /app/target/release/controller .

CMD ["./controller"]
