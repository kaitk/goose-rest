// goose-http's REST benchmark tiers on actix-web, each route on actix-web's
// App, scopes, and resources with its extractors and middleware, run as
// TechEmpower's actix entry runs its actix-web server: actix-server with
// WORKERS workers, each a single-threaded runtime, a backlog of 1,024,
// actix-http's HTTP/1 service with the OS's keep-alive and no request
// timeout, and snmalloc (NOTES.md).
//
//   REST_DATA=DIR TIER=a|b|c|d|f|r|m WORKERS=n [JSON=template] [ROUTES=FILE]
//       rest-actix-web [port]
//
// TIER picks the dataset and the routes: tier D serves tier C's beside its
// own, and tier M tier A's behind its middleware.

mod arena;
mod extract;
mod framework;
mod heavy;
mod snow;
mod writes;

use std::time::Duration;

use actix_http::{HttpService, KeepAlive};
use actix_server::Server;
use actix_service::map_config;
use actix_web::dev::AppConfig;
use actix_web::{App, web};
use rest_app::Tier;

#[global_allocator]
static ALLOC: snmalloc_rs::SnMalloc = snmalloc_rs::SnMalloc;

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    let config = rest_app::init("rest-actix-web");
    let tier = config.tier;
    Server::build()
        .backlog(1024)
        .workers(config.workers)
        .bind("rest-actix-web", ("0.0.0.0", config.port), move || {
            // Paths no tier's routes take answer 404 with no body, as tier
            // A's unknown paths do; a tier's scope answers its own 404.
            let app = App::new().default_service(web::to(|| async { extract::reply(rest_app::arena::not_found()) }));
            let app = match tier {
                Tier::A => app.configure(arena::routes),
                Tier::B => app.configure(snow::routes),
                Tier::C => app.configure(heavy::routes),
                Tier::D => app.configure(heavy::routes).configure(writes::routes),
                Tier::F => app.configure(framework::micro),
                Tier::R => app.configure(framework::github),
                Tier::M => app.configure(framework::stack),
            };
            HttpService::build()
                .keep_alive(KeepAlive::Os)
                .client_request_timeout(Duration::ZERO)
                .h1(map_config(app, |_| AppConfig::default()))
                .tcp()
        })?
        .run()
        .await
}
