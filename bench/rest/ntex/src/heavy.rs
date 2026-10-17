// Tier C, the scope /api/v2. Each resource takes its methods by guard and
// has the bearer middleware, so an unknown path or method falls to the
// scope's 404 before the token is checked. An id that isn't a number is
// Path's error and a query that Query refuses Query's, which the error domain
// answers 404 and 400.

use ntex::web::error::QueryPayloadError;
use ntex::web::types::{Path, Query};
use ntex::web::{self, HttpResponse, ServiceConfig};
use rest_app::heavy;
use serde::Deserialize;

use crate::extract::{Bench, HEAVY_BEARER, get_or_head, reply};

pub fn routes(cfg: &mut ServiceConfig<Bench>) {
    let resource = |path: &str| web::resource(path).guard(get_or_head()).middleware(HEAVY_BEARER);
    cfg.service(web::scope("/api/v2")
                    .service(resource("/schedule/version").to(version))
                    .service(resource("/schedule/bookings").to(bookings))
                    .service(resource("/schedule/shifts").to(shifts))
                    .service(resource("/encounters/{id}").to(encounter))
                    .service(resource("/clients/{id}/encounters").to(client_encounters))
                    .service(resource("/clients/{id}").to(client))
                    .default_service(web::to(async || reply(heavy::not_found()))));
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

async fn version(q: Query<SinceQuery>) -> HttpResponse {
    reply(heavy::version(q.since.as_deref()))
}

async fn bookings(q: Query<RangeQuery>) -> HttpResponse {
    reply(heavy::bookings(q.start.as_deref(), q.end.as_deref(), q.staff.as_deref()))
}

async fn shifts(q: Query<RangeQuery>) -> HttpResponse {
    reply(heavy::shifts(q.start.as_deref(), q.end.as_deref(), q.staff.as_deref()))
}

async fn encounter(id: Path<usize>) -> HttpResponse {
    reply(heavy::encounter(id.into_inner()))
}

// The client is looked up before the query is read, so its query is a Result.
async fn client_encounters(id: Path<usize>, query: Result<Query<LimitQuery>, QueryPayloadError>) -> HttpResponse {
    reply(match (heavy::client_of(id.into_inner()), query) {
        (Err(r), _) => r,
        (Ok(c), Ok(q)) => heavy::client_encounters(c, q.limit.as_deref()),
        (Ok(_), Err(_)) => heavy::bad_request(),
    })
}

async fn client(id: Path<usize>) -> HttpResponse {
    reply(heavy::client(id.into_inner()))
}
