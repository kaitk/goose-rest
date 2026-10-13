// Tier B, under /api/v1, whose unknown paths and methods answer snowtime's
// 404. The extractors check in snowtime's order: SameOrigin on writes, then
// Signed; membership, the query, and the body follow in the handler, so a
// query that Query refuses is a 400 only after a 403 for a non-member.

use axum::Router;
use axum::body::Bytes;
use axum::extract::rejection::QueryRejection;
use axum::extract::{Path, Query};
use axum::middleware;
use axum::routing::{MethodRouter, get, patch, post};
use rest_app::snow::{self, Membership};
use serde::Deserialize;

use crate::extract::{R, SameOrigin, Signed, drain};

pub fn routes() -> Router {
    let not_found = || async { R(snow::not_found()) };
    let drained = |route: MethodRouter| -> MethodRouter { route.layer(middleware::from_fn(drain)) };
    let v1 = Router::new()
        .route("/session", get(session))
        .route("/timer", get(timer))
        .route("/timer/stop", drained(post(stop_timer)))
        .route("/organizations/{org}/entries", get(list_entries))
        .route("/organizations/{org}/projects", get(list_projects))
        .route("/organizations/{org}/entries/{id}", drained(patch(patch_entry)))
        .route("/organizations/{org}/timer/start", drained(post(start_timer)))
        .method_not_allowed_fallback(not_found)
        .fallback(not_found);
    Router::new().nest("/api/v1", v1)
}

#[derive(Deserialize)]
struct EntriesQuery {
    from: Option<String>,
    to: Option<String>,
    #[serde(rename = "userId")]
    user_id: Option<String>,
}

#[derive(Deserialize)]
struct ProjectsQuery {
    #[serde(rename = "includeArchived")]
    include_archived: Option<String>,
}

fn member(u: usize, org: &str) -> Result<Membership, R> {
    snow::member(u, org).map_err(R)
}

async fn session(signed: Option<Signed>) -> R {
    R(snow::session(signed.map(|Signed(u)| u)))
}

async fn timer(Signed(u): Signed) -> R {
    R(snow::timer(u))
}

async fn stop_timer(_: SameOrigin, Signed(u): Signed, body: Bytes) -> R {
    R(snow::stop_timer(u, &body))
}

async fn list_entries(Signed(u): Signed, Path(org): Path<String>, query: Result<Query<EntriesQuery>, QueryRejection>)
                      -> Result<R, R> {
    let m = member(u, &org)?;
    let Ok(Query(q)) = query else { return Ok(R(snow::invalid())) };
    Ok(R(snow::list_entries(&m, q.from.as_deref(), q.to.as_deref(), q.user_id.as_deref())))
}

async fn list_projects(Signed(u): Signed, Path(org): Path<String>,
                       query: Result<Query<ProjectsQuery>, QueryRejection>) -> Result<R, R> {
    let m = member(u, &org)?;
    let Ok(Query(q)) = query else { return Ok(R(snow::invalid())) };
    Ok(R(snow::list_projects(&m, q.include_archived.as_deref())))
}

async fn patch_entry(_: SameOrigin, Signed(u): Signed, Path((org, id)): Path<(String, String)>, body: Bytes)
                     -> Result<R, R> {
    let m = member(u, &org)?;
    Ok(R(snow::patch_entry(&m, &id, &body)))
}

async fn start_timer(_: SameOrigin, Signed(u): Signed, Path(org): Path<String>, body: Bytes) -> Result<R, R> {
    let m = member(u, &org)?;
    Ok(R(snow::start_timer(&m, &body)))
}
