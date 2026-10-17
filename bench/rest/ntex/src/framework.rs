// goose-rest's framework tiers (bench/rest/tiers), on ntex's own types:
//
//   F   GET /, GET /id/{id}?name= with x-powered-by, and POST /json echoing
//       its body as a serde_json Value, members in order
//   R   each of ROUTES's lines on a resource, answering its number and its
//       parameters' values
//   M   tier A's routes behind the App's middleware, outermost first,
//       Server-Timing, ntex-cors, and a bearer check

use std::time::Instant;

use ntex::http::Method;
use ntex::http::header::{AUTHORIZATION, CONTENT_TYPE, HeaderName, HeaderValue};
use ntex::web::types::{Json, Path, Query};
use ntex::web::{self, HttpRequest, Responder, ServiceConfig, WebRequest, WebResponse};
use ntex::{Ctx, Middleware, Service};
use ntex_cors::{Cors, CorsMiddleware};
use rest_app::Reply;
use serde::Deserialize;
use serde_json::Value;

use crate::extract::{Bearer, Bench, get};

pub fn micro(cfg: &mut ServiceConfig<Bench>) {
    cfg.service(web::resource("/").route(get().to(async || "Hi")))
        .service(web::resource("/id/{id}").route(get().to(id)))
        .service(web::resource("/json").route(web::post().to(echo)));
}

#[derive(Deserialize)]
struct NameQuery {
    #[serde(default)]
    name: String,
}

async fn id(id: Path<String>, q: Query<NameQuery>) -> impl Responder<Bench> {
    format!("{} {}", id.into_inner(), q.name).with_header("x-powered-by", "benchmark")
}

async fn echo(body: Json<Value>) -> Json<Value> {
    body
}

// Route n of the file answers n. ntex takes the first resource that matches a
// path, so a path's routes share one resource, in the file's order of first
// appearance; a method a path lacks is its 405.
pub fn github(cfg: &mut ServiceConfig<Bench>) {
    let mut paths: Vec<(String, Vec<(Method, usize)>)> = Vec::new();
    for (k, (method, path)) in rest_app::github_routes().into_iter().enumerate() {
        let method = Method::from_bytes(method.as_bytes()).expect("a method");
        match paths.iter_mut().find(|(p, _)| *p == path) {
            Some((_, routes)) => routes.push((method, k + 1)),
            None => paths.push((path, vec![(method, k + 1)])),
        }
    }
    for (path, routes) in paths {
        let routes: Vec<_> = routes.into_iter().map(|(method, n)| {
            web::method(method).to(async move |req: HttpRequest| {
                rest_app::numbered(n, req.match_info().iter().map(|(_, v)| v))
            })
        }).collect();
        cfg.service(web::resource(path.as_str()).route(routes));
    }
}

static SERVER_TIMING: HeaderName = HeaderName::from_static("server-timing");

// Server-Timing on every answer, as middleware.
pub struct Timing;

pub struct TimingService<S> {
    service: S,
}

impl<S, St> Middleware<S, St> for Timing {
    type Service = TimingService<S>;

    fn create(&self, _: &St, service: S) -> Self::Service {
        TimingService { service }
    }
}

impl<S, St, In> Service<St, WebRequest<In>> for TimingService<S>
where
    S: Service<St, WebRequest<In>, Res = WebResponse>,
{
    type Res = WebResponse;
    type Error = S::Error;

    ntex::forward_ready!(St, service);
    ntex::forward_shutdown!(St, service);

    async fn call(&self, req: WebRequest<In>, ctx: Ctx<'_, Self, St>) -> Result<WebResponse, S::Error> {
        let start = Instant::now();
        let mut res = ctx.call(&self.service, req).await?;
        let ms = start.elapsed().as_secs_f64() * 1000.0;
        res.headers_mut().insert(SERVER_TIMING.clone(), HeaderValue::try_from(format!("app;dur={ms:.3}")).unwrap());
        Ok(res)
    }
}

// Tier M's CORS and bearer check. main.rs adds them to the App after Timing,
// which ntex runs in the order they're added, outermost first.
pub fn cors() -> CorsMiddleware<Bench> {
    Cors::new()
        .allowed_origin(rest_app::CORS_ORIGIN)
        .allowed_methods([Method::GET, Method::POST])
        .allowed_headers([AUTHORIZATION, CONTENT_TYPE])
        .build()
}

pub const BEARER: Bearer = Bearer { valid: rest_app::is_bearer, refused: || Reply::empty(401) };
