use actix_web::{
    get, middleware, web::Data, App, HttpRequest, HttpResponse, HttpServer, Responder,
};
use dotenv::dotenv;
use prometheus::{Encoder, TextEncoder};
use std::{io, sync::Arc};
use tracing::{info, Level};

use ext_cardano_dbsync::{controller, metrics as metrics_collector, State};

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

    tracing_subscriber::fmt().with_max_level(Level::INFO).init();

    let state = Arc::new(State::try_new().await?);

    let controller = tokio::spawn(controller::run(state.clone()));
    let metrics_collector = tokio::spawn(metrics_collector::run_metrics_collector(state.clone()));

    let addr = std::env::var("ADDR").unwrap_or("0.0.0.0:8080".into());

    let server = HttpServer::new(move || {
        App::new()
            .app_data(Data::new(state.clone()))
            .wrap(middleware::Logger::default())
            .service(health)
            .service(metrics)
    })
    .bind(&addr)?;
    info!({ addr }, "metrics server running");

    let signal = tokio::spawn(async {
        tokio::signal::ctrl_c().await.expect("fail to exit");
        std::process::exit(0);
    });

    tokio::join!(server.run(), controller, metrics_collector, signal).0?;

    Ok(())
}
