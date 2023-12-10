use actix_web::{
    get, middleware, web::Data, App, HttpRequest, HttpResponse, HttpServer, Responder,
};
use dotenv::dotenv;
use prometheus::{Encoder, TextEncoder};
use std::{io, sync::Arc};
use tracing::error;

use ext_cardano_dbsync::{controller, metrics as metrics_collector, Config, State};

#[get("/metrics")]
async fn metrics(c: Data<Arc<State>>, _req: HttpRequest) -> impl Responder {
    let metrics = c.metrics_collected();
    let encoder = TextEncoder::new();
    let mut buffer = vec![];
    encoder.encode(&metrics, &mut buffer).unwrap();
    HttpResponse::Ok().body(buffer)
}

#[get("/health")]
async fn health(_: HttpRequest) -> impl Responder {
    HttpResponse::Ok().json("healthy")
}

#[tokio::main]
async fn main() -> io::Result<()> {
    dotenv().ok();

    let state = Arc::new(State::new());
    let config = Config::try_new().unwrap();

    let controller = controller::run(state.clone(), config.clone());
    let metrics_collector = metrics_collector::run_metrics_collector(state.clone(), config.clone());

    let addr = std::env::var("ADDR").unwrap_or("0.0.0.0:8080".into());

    let server = HttpServer::new(move || {
        App::new()
            .app_data(Data::new(state.clone()))
            .wrap(middleware::Logger::default())
            .service(health)
            .service(metrics)
    })
    .bind(addr)?;

    let result = tokio::join!(controller, metrics_collector, server.run()).1;
    if let Err(err) = result {
        error!("{err}");
        std::process::exit(1)
    }

    Ok(())
}
