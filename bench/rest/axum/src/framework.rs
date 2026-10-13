// goose-rest's framework tiers (bench/rest/tiers), on axum's own types:
//
//   F   GET /, GET /id/{id}?name= with x-powered-by, and POST /json echoing
//       its body as a serde_json Value, members in order
//   R   each of ROUTES's lines on the router, answering its number and its
//       parameters' values
//   M   tier A's routes behind, outermost first, Server-Timing, tower-http's
//       CORS, and a bearer check

use std::time::Instant;

use axum::extract::{Json, Path, Query, Request};
use axum::http::header::{AUTHORIZATION, CONTENT_TYPE};
use axum::http::{HeaderName, HeaderValue, Method};
use axum::middleware::{self, Next};
use axum::response::{IntoResponse, Response};
use axum::routing::{MethodFilter, get, on, post};
use axum::Router;
use rest_app::Reply;
use serde::Deserialize;
use serde_json::Value;
use tower_http::cors::CorsLayer;

use crate::extract::R;

pub fn micro() -> Router {
    Router::new()
        .route("/", get(|| async { "Hi" }))
        .route("/id/{id}", get(id))
        .route("/json", post(echo))
}

#[derive(Deserialize)]
struct NameQuery {
    #[serde(default)]
    name: String,
}

async fn id(Path(id): Path<String>, Query(q): Query<NameQuery>) -> impl IntoResponse {
    ([("x-powered-by", "benchmark")], format!("{id} {}", q.name))
}

async fn echo(Json(body): Json<Value>) -> Json<Value> {
    Json(body)
}

// Route n of the file answers n; a path no line has is the router's 404, and
// a method a path lacks its 405.
pub fn github() -> Router {
    let mut router = Router::new();
    for (k, (method, path)) in rest_app::github_routes().into_iter().enumerate() {
        let n = k + 1;
        let method = Method::from_bytes(method.as_bytes()).expect("a method");
        let filter = MethodFilter::try_from(method).expect("a method axum routes");
        let route = if path.contains('{') {
            on(filter, move |Path(values): Path<Vec<String>>| async move {
                rest_app::numbered(n, values.iter().map(String::as_str))
            })
        } else {
            on(filter, move || async move { n.to_string() })
        };
        router = router.route(&path, route);
    }
    router
}

static SERVER_TIMING: HeaderName = HeaderName::from_static("server-timing");

async fn timing(req: Request, next: Next) -> Response {
    let start = Instant::now();
    let mut res = next.run(req).await;
    let ms = start.elapsed().as_secs_f64() * 1000.0;
    res.headers_mut().insert(SERVER_TIMING.clone(), HeaderValue::from_str(&format!("app;dur={ms:.3}")).unwrap());
    res
}

async fn bearer(req: Request, next: Next) -> Response {
    if rest_app::is_bearer(req.headers().get(AUTHORIZATION).map(HeaderValue::as_bytes)) {
        next.run(req).await
    } else {
        R(Reply::empty(401)).into_response()
    }
}

// Tier M's stack over a router of tier A's routes and its fallback.
pub fn stack(app: Router) -> Router {
    let cors = CorsLayer::new()
        .allow_origin(HeaderValue::from_static(rest_app::CORS_ORIGIN))
        .allow_methods([Method::GET, Method::POST])
        .allow_headers([AUTHORIZATION, CONTENT_TYPE]);
    app.layer(middleware::from_fn(bearer)).layer(cors).layer(middleware::from_fn(timing))
}
