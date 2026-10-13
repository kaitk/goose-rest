// Tier B, the scope /api/v1, whose unknown paths and methods answer
// snowtime's 404. The extractors check in snowtime's order: SameOrigin on
// writes, then Signed; membership, the query, and the body follow in the
// handler, so a query that Query refuses is a 400 only after a 403 for a
// non-member.

use actix_web::web::{self, Bytes, ServiceConfig};
use actix_web::{Error, HttpResponse};
use rest_app::Reply;
use rest_app::snow;
use serde::Deserialize;

use crate::extract::{SameOrigin, Signed, get, reply};

pub fn routes(cfg: &mut ServiceConfig) {
    let not_found = || web::to(|| async { reply(snow::not_found()) });
    let resource = |path: &str| web::resource(path).default_service(not_found());
    cfg.service(web::scope("/api/v1")
                    .service(resource("/session").route(get().to(session)))
                    .service(resource("/timer").route(get().to(timer)))
                    .service(resource("/timer/stop").route(web::post().to(stop_timer)))
                    .service(resource("/organizations/{org}/entries").route(get().to(list_entries)))
                    .service(resource("/organizations/{org}/projects").route(get().to(list_projects)))
                    .service(resource("/organizations/{org}/entries/{id}").route(web::patch().to(patch_entry)))
                    .service(resource("/organizations/{org}/timer/start").route(web::post().to(start_timer)))
                    .default_service(not_found()));
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

// A route's answer, or its membership check's 403.
fn answer(r: Result<Reply, Reply>) -> HttpResponse<Bytes> {
    reply(r.unwrap_or_else(|refused| refused))
}

async fn session(signed: Option<Signed>) -> HttpResponse<Bytes> {
    reply(snow::session(signed.map(|Signed(u)| u)))
}

async fn timer(Signed(u): Signed) -> HttpResponse<Bytes> {
    reply(snow::timer(u))
}

async fn stop_timer(_: SameOrigin, Signed(u): Signed, body: Bytes) -> HttpResponse<Bytes> {
    reply(snow::stop_timer(u, &body))
}

async fn list_entries(Signed(u): Signed, org: web::Path<String>,
                      query: Result<web::Query<EntriesQuery>, Error>) -> HttpResponse<Bytes> {
    answer(snow::member(u, &org).map(|m| match query {
        Ok(q) => snow::list_entries(&m, q.from.as_deref(), q.to.as_deref(), q.user_id.as_deref()),
        Err(_) => snow::invalid(),
    }))
}

async fn list_projects(Signed(u): Signed, org: web::Path<String>,
                       query: Result<web::Query<ProjectsQuery>, Error>) -> HttpResponse<Bytes> {
    answer(snow::member(u, &org).map(|m| match query {
        Ok(q) => snow::list_projects(&m, q.include_archived.as_deref()),
        Err(_) => snow::invalid(),
    }))
}

async fn patch_entry(_: SameOrigin, Signed(u): Signed, path: web::Path<(String, String)>, body: Bytes)
                     -> HttpResponse<Bytes> {
    let (org, id) = path.into_inner();
    answer(snow::member(u, &org).map(|m| snow::patch_entry(&m, &id, &body)))
}

async fn start_timer(_: SameOrigin, Signed(u): Signed, org: web::Path<String>, body: Bytes) -> HttpResponse<Bytes> {
    answer(snow::member(u, &org).map(|m| snow::start_timer(&m, &body)))
}
