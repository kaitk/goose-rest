// Tier C, under /api/v2, behind the bearer middleware, whose unknown paths
// and methods answer 404 before it. An id that isn't a number is Path's
// rejection, answered 404, and a query that Query refuses 400.

use axum::Router;
use axum::extract::rejection::{PathRejection, QueryRejection};
use axum::extract::{Path, Query};
use axum::middleware;
use axum::routing::get;
use rest_app::heavy;
use serde::Deserialize;

use crate::extract::{R, bearer};

pub fn routes() -> Router {
    let not_found = || async { R(heavy::not_found()) };
    let v2 = Router::new()
        .route("/schedule/version", get(version))
        .route("/schedule/bookings", get(bookings))
        .route("/schedule/shifts", get(shifts))
        .route("/encounters/{id}", get(encounter))
        .route("/clients/{id}/encounters", get(client_encounters))
        .route("/clients/{id}", get(client))
        .route_layer(middleware::from_fn(bearer))
        .method_not_allowed_fallback(not_found)
        .fallback(not_found);
    Router::new().nest("/api/v2", v2)
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

type Id = Result<Path<usize>, PathRejection>;

async fn version(query: Result<Query<SinceQuery>, QueryRejection>) -> R {
    R(match query {
        Ok(Query(q)) => heavy::version(q.since.as_deref()),
        Err(_) => heavy::bad_request(),
    })
}

async fn bookings(query: Result<Query<RangeQuery>, QueryRejection>) -> R {
    R(match query {
        Ok(Query(q)) => heavy::bookings(q.start.as_deref(), q.end.as_deref(), q.staff.as_deref()),
        Err(_) => heavy::bad_request(),
    })
}

async fn shifts(query: Result<Query<RangeQuery>, QueryRejection>) -> R {
    R(match query {
        Ok(Query(q)) => heavy::shifts(q.start.as_deref(), q.end.as_deref(), q.staff.as_deref()),
        Err(_) => heavy::bad_request(),
    })
}

async fn encounter(id: Id) -> R {
    R(match id {
        Ok(Path(id)) => heavy::encounter(id),
        Err(_) => heavy::not_found(),
    })
}

async fn client_encounters(id: Id, query: Result<Query<LimitQuery>, QueryRejection>) -> R {
    let Ok(Path(id)) = id else { return R(heavy::not_found()) };
    R(match (heavy::client_of(id), query) {
        (Err(r), _) => r,
        (Ok(c), Ok(Query(q))) => heavy::client_encounters(c, q.limit.as_deref()),
        (Ok(_), Err(_)) => heavy::bad_request(),
    })
}

async fn client(id: Id) -> R {
    R(match id {
        Ok(Path(id)) => heavy::client(id),
        Err(_) => heavy::not_found(),
    })
}
