// goose-http's REST benchmark tiers on axum, each route on axum's router with
// its extractors and middleware, run as TechEmpower's axum entry runs:
// WORKERS threads, each a current-thread Tokio runtime with its own
// SO_REUSEPORT listener, serving HTTP/1 through hyper-util with pipelined
// flushes, and mimalloc (NOTES.md).
//
//   REST_DATA=DIR TIER=a|b|c|d|f|r|m WORKERS=n [JSON=template] [ROUTES=FILE]
//       rest-axum [port]
//
// TIER picks the dataset and the routes: tier D serves tier C's beside its
// own, and tier M tier A's behind its middleware.

mod arena;
mod extract;
mod framework;
mod heavy;
mod snow;
mod writes;

use std::io;
use std::net::{Ipv4Addr, SocketAddr};

use axum::Router;
use axum::http::HeaderValue;
use axum::http::header::SERVER;
use hyper::Request;
use hyper::body::Incoming;
use hyper_util::rt::{TokioExecutor, TokioIo};
use mimalloc::MiMalloc;
use rest_app::Tier;
use socket2::{Domain, Socket, Type};
use tower::Service;
use tower_http::set_header::SetResponseHeaderLayer;

#[global_allocator]
static GLOBAL: MiMalloc = MiMalloc;

// Each tier's routes. Paths no tier's router takes answer 404 with no body,
// as tier A's unknown paths do; a tier's router under its own prefix answers
// its own 404.
fn app(tier: Tier) -> Router {
    let routes = match tier {
        Tier::A | Tier::M => arena::routes(),
        Tier::B => snow::routes(),
        Tier::C => heavy::routes(),
        Tier::D => heavy::routes().merge(writes::routes()),
        Tier::F => framework::micro(),
        Tier::R => return framework::github().layer(server_field()),
    };
    let app = routes.fallback(|| async { extract::R(rest_app::arena::not_found()) });
    let app = if tier == Tier::M { framework::stack(app) } else { app };
    app.layer(server_field())
}

fn server_field() -> SetResponseHeaderLayer<HeaderValue> {
    SetResponseHeaderLayer::overriding(SERVER, HeaderValue::from_static("Axum"))
}

fn listener(port: u16) -> io::Result<tokio::net::TcpListener> {
    let addr = SocketAddr::from((Ipv4Addr::UNSPECIFIED, port));
    let socket = Socket::new(Domain::IPV4, Type::STREAM, None)?;
    socket.set_reuse_port(true)?;
    socket.set_reuse_address(true)?;
    socket.set_nonblocking(true)?;
    socket.set_tcp_nodelay(true)?;
    socket.bind(&addr.into())?;
    socket.listen(4096)?;
    tokio::net::TcpListener::from_std(socket.into())
}

async fn serve(tier: Tier, port: u16) {
    let app = app(tier);
    let listener = listener(port).expect("couldn't bind to address");
    loop {
        let Ok((socket, _)) = listener.accept().await else { continue };
        socket.set_nodelay(true).expect("could not set TCP_NODELAY");
        let tower_service = app.clone();
        tokio::spawn(async move {
            let service = hyper::service::service_fn(move |request: Request<Incoming>| {
                tower_service.clone().call(request)
            });
            let _ = hyper_util::server::conn::auto::Builder::new(TokioExecutor::new())
                .http1()
                .pipeline_flush(true)
                .serve_connection(TokioIo::new(socket), service)
                .await;
        });
    }
}

fn runtime() -> tokio::runtime::Runtime {
    tokio::runtime::Builder::new_current_thread().enable_all().build().unwrap()
}

fn main() {
    let config = rest_app::init("rest-axum");
    let (tier, port) = (config.tier, config.port);
    for _ in 1..config.workers {
        std::thread::spawn(move || runtime().block_on(serve(tier, port)));
    }
    runtime().block_on(serve(tier, port));
}
