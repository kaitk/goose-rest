// Plod's framework tiers (bench/rest/tiers), on actix-web's own types:
//
//   F   GET /, GET /id/{id}?name= with x-powered-by, and POST /json echoing
//       its body as a serde_json Value, members in order
//   R   each of ROUTES's lines on a resource, answering its number and its
//       parameters' values
//   M   tier A's routes in a scope behind, outermost first, Server-Timing,
//       actix-cors, and a bearer check

use std::time::Instant;

use actix_cors::Cors;
use actix_web::body::{BoxBody, EitherBody, MessageBody};
use actix_web::dev::{ServiceRequest, ServiceResponse};
use actix_web::http::Method;
use actix_web::http::header::{AUTHORIZATION, CONTENT_TYPE, HeaderName, HeaderValue};
use actix_web::middleware::{Next, from_fn};
use actix_web::web::{self, ServiceConfig};
use actix_web::{Error, HttpRequest, Responder};
use rest_app::Reply;
use serde::Deserialize;
use serde_json::Value;

use crate::extract::{get, reply};

pub fn micro(cfg: &mut ServiceConfig) {
    cfg.service(web::resource("/").route(get().to(|| async { "Hi" })))
        .service(web::resource("/id/{id}").route(get().to(id)))
        .service(web::resource("/json").route(web::post().to(echo)));
}

#[derive(Deserialize)]
struct NameQuery {
    #[serde(default)]
    name: String,
}

async fn id(id: web::Path<String>, q: web::Query<NameQuery>) -> impl Responder {
    format!("{id} {}", q.name).customize().insert_header(("x-powered-by", "benchmark"))
}

async fn echo(body: web::Json<Value>) -> web::Json<Value> {
    body
}

// Route n of the file answers n. actix-web takes the first resource that
// matches a path, so a path's routes share one resource, in the file's order
// of first appearance; a method a path lacks is its 405.
pub fn github(cfg: &mut ServiceConfig) {
    let mut paths: Vec<(String, Vec<(Method, usize)>)> = Vec::new();
    for (k, (method, path)) in rest_app::github_routes().into_iter().enumerate() {
        let method = Method::from_bytes(method.as_bytes()).expect("a method");
        match paths.iter_mut().find(|(p, _)| *p == path) {
            Some((_, routes)) => routes.push((method, k + 1)),
            None => paths.push((path, vec![(method, k + 1)])),
        }
    }
    for (path, routes) in paths {
        let mut resource = web::resource(path);
        for (method, n) in routes {
            resource = resource.route(web::method(method).to(move |req: HttpRequest| async move {
                rest_app::numbered(n, req.match_info().iter().map(|(_, v)| v))
            }));
        }
        cfg.service(resource);
    }
}

static SERVER_TIMING: HeaderName = HeaderName::from_static("server-timing");

async fn timing(req: ServiceRequest, next: Next<impl MessageBody + 'static>)
                -> Result<ServiceResponse<impl MessageBody>, Error> {
    let start = Instant::now();
    let mut res = next.call(req).await?;
    let ms = start.elapsed().as_secs_f64() * 1000.0;
    res.headers_mut().insert(SERVER_TIMING.clone(), HeaderValue::from_str(&format!("app;dur={ms:.3}")).unwrap());
    Ok(res)
}

async fn bearer(req: ServiceRequest, next: Next<impl MessageBody + 'static>)
                -> Result<ServiceResponse<EitherBody<impl MessageBody, BoxBody>>, Error> {
    if rest_app::is_bearer(req.headers().get(AUTHORIZATION).map(HeaderValue::as_bytes)) {
        next.call(req).await.map(ServiceResponse::map_into_left_body)
    } else {
        Ok(req.into_response(reply(Reply::empty(401)).map_into_boxed_body()).map_into_right_body())
    }
}

// Tier M: tier A's routes and its 404 in a scope over every path, with the
// stack as the scope's middleware.
pub fn stack(cfg: &mut ServiceConfig) {
    let cors = Cors::default()
        .allowed_origin(rest_app::CORS_ORIGIN)
        .allowed_methods([Method::GET, Method::POST])
        .allowed_headers([AUTHORIZATION, CONTENT_TYPE]);
    cfg.service(web::scope("")
                    .configure(crate::arena::routes)
                    .default_service(web::to(|| async { reply(rest_app::arena::not_found()) }))
                    .wrap(from_fn(bearer))
                    .wrap(cors)
                    .wrap(from_fn(timing)));
}
