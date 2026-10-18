// goose-http's REST benchmark tiers on ntex, each route on ntex's App,
// scopes, and resources with its extractors, error domain, and middleware,
// run as TechEmpower's ntex entry runs its server: ntex-server with WORKERS
// workers, each a single-threaded runtime pinned to a CPU, a backlog of
// 1,024, ntex's HTTP/1 service with the OS's keep-alive and no request
// timeouts, and mimalloc (NOTES.md). On Linux the runtime is ntex's native
// one on io_uring.
//
//   REST_DATA=DIR TIER=a|b|c|d|f|r|m WORKERS=n [JSON=template] [ROUTES=FILE]
//       [AFFINITY=0] rest-ntex [port]
//
// AFFINITY=0 leaves the workers unpinned, as every other server runs.
//
// TIER picks the dataset and the routes: tier D serves tier C's beside its
// own, and tier M tier A's behind its middleware.

mod arena;
mod extract;
mod framework;
mod heavy;
mod snow;
mod writes;

use ntex::SharedCfg;
use ntex::http::{HttpService, HttpServiceConfig, KeepAlive};
use ntex::time::Seconds;
use ntex::web::{self, App};
use rest_app::Tier;

use crate::extract::{Bench, reply};

#[global_allocator]
static ALLOC: mimalloc::MiMalloc = mimalloc::MiMalloc;

// Serves the App that $app builds on each worker. App::middleware changes the
// App's type, so tier M's App and the others' are served apart.
macro_rules! serve {
    ($config:expr, $app:expr) => {{
        let config = $config;
        let tier = config.tier;
        let http = HttpServiceConfig::new()
            .set_keepalive(KeepAlive::Os)
            .set_client_timeout(Seconds::ZERO)
            .set_headers_read_rate(Seconds::ZERO, Seconds::ZERO, 0)
            .set_payload_read_rate(Seconds::ZERO, Seconds::ZERO, 0);
        let server = ntex::server::build().backlog(1024).workers(config.workers);
        let server = if std::env::var("AFFINITY").as_deref() == Ok("0") { server } else { server.enable_affinity() };
        server
            .bind("rest-ntex", ("0.0.0.0", config.port), SharedCfg::new("rest-ntex").add(http), async move |_| {
                // Paths no tier's routes take answer 404 with no body, as
                // tier A's unknown paths do; a tier's scope answers its own.
                let app = $app(tier).default_service(web::to(async || reply(rest_app::arena::not_found())));
                HttpService::h1(app.build_with::<()>(Bench(tier)))
            })?
            .run()
            .await
    }};
}

#[ntex::main]
async fn main() -> std::io::Result<()> {
    let config = rest_app::init("rest-ntex");
    if config.tier == Tier::M {
        serve!(config, |_| App::<Bench>::new()
            .middleware(framework::Timing)
            .middleware(framework::cors())
            .middleware(framework::BEARER)
            .configure(arena::routes))
    } else {
        serve!(config, |tier| App::<Bench>::new().configure(|cfg| match tier {
            Tier::A => arena::routes(cfg),
            Tier::B => snow::routes(cfg),
            Tier::C => heavy::routes(cfg),
            Tier::D => {
                heavy::routes(cfg);
                writes::routes(cfg);
            }
            Tier::F => framework::micro(cfg),
            Tier::R => framework::github(cfg),
            Tier::M => unreachable!(),
        }))
    }
}
