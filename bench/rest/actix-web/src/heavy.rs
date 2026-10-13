// Tier C, the scope /api/v2, each route behind the bearer middleware, whose
// unknown paths and methods answer 404 before it. An id that isn't a number
// is Path's error and a query that Query refuses Query's, answered 404 and
// 400 by the scope's PathConfig and QueryConfig handlers.

use actix_web::middleware::from_fn;
use actix_web::web::{self, Bytes, ServiceConfig};
use actix_web::{Error, HttpResponse};
use rest_app::heavy;
use serde::Deserialize;

use crate::extract::{bearer, get, refuse, reply};

pub fn routes(cfg: &mut ServiceConfig) {
    let not_found = || web::to(|| async { reply(heavy::not_found()) });
    let resource = |path: &str| web::resource(path).default_service(not_found());
    let path = web::PathConfig::default().error_handler(|_, _| refuse(heavy::not_found()));
    let query = web::QueryConfig::default().error_handler(|_, _| refuse(heavy::bad_request()));
    cfg.service(web::scope("/api/v2")
                    .app_data(path)
                    .app_data(query)
                    .service(resource("/schedule/version").route(get().to(version).wrap(from_fn(bearer))))
                    .service(resource("/schedule/bookings").route(get().to(bookings).wrap(from_fn(bearer))))
                    .service(resource("/schedule/shifts").route(get().to(shifts).wrap(from_fn(bearer))))
                    .service(resource("/encounters/{id}").route(get().to(encounter).wrap(from_fn(bearer))))
                    .service(resource("/clients/{id}/encounters")
                                 .route(get().to(client_encounters).wrap(from_fn(bearer))))
                    .service(resource("/clients/{id}").route(get().to(client).wrap(from_fn(bearer))))
                    .default_service(not_found()));
}

#[derive(Deserialize)]
struct SinceQuery {
    since: Option<String>,
}

#[derive(Deserialize)]
struct RangeQuery {
    start: Option<String>,
    end: Option<String>,
    staff: Option<String>,
}

#[derive(Deserialize)]
struct LimitQuery {
    limit: Option<String>,
}

async fn version(q: web::Query<SinceQuery>) -> HttpResponse<Bytes> {
    reply(heavy::version(q.since.as_deref()))
}

async fn bookings(q: web::Query<RangeQuery>) -> HttpResponse<Bytes> {
    reply(heavy::bookings(q.start.as_deref(), q.end.as_deref(), q.staff.as_deref()))
}

async fn shifts(q: web::Query<RangeQuery>) -> HttpResponse<Bytes> {
    reply(heavy::shifts(q.start.as_deref(), q.end.as_deref(), q.staff.as_deref()))
}

async fn encounter(id: web::Path<usize>) -> HttpResponse<Bytes> {
    reply(heavy::encounter(id.into_inner()))
}

// The client is looked up before the query is read, so its query is a Result.
async fn client_encounters(id: web::Path<usize>, query: Result<web::Query<LimitQuery>, Error>)
                           -> HttpResponse<Bytes> {
    reply(match (heavy::client_of(id.into_inner()), query) {
        (Err(r), _) => r,
        (Ok(c), Ok(q)) => heavy::client_encounters(c, q.limit.as_deref()),
        (Ok(_), Err(_)) => heavy::bad_request(),
    })
}

async fn client(id: web::Path<usize>) -> HttpResponse<Bytes> {
    reply(heavy::client(id.into_inner()))
}
