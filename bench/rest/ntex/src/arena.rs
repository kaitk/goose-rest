// Tier A. An id that isn't a number is Path's error, which the error domain
// answers 404 as an unknown id; a body that isn't a Write is Json's error,
// answered 422 after the id is looked up. A method a resource lacks answers
// 404, as an unknown path does.

use ntex::web::error::JsonPayloadError;
use ntex::web::types::{Json, Path};
use ntex::web::{self, HttpRequest, HttpResponse, ServiceConfig};
use rest_app::arena::{self, Write};

use crate::extract::{Bench, get, reply};

pub fn routes(cfg: &mut ServiceConfig<Bench>) {
    let not_found = || web::to(async || reply(arena::not_found()));
    cfg.service(web::resource("/api/items/{id}")
                    .route(get().to(item))
                    .route(web::post().to(write))
                    .default_service(not_found()))
        .service(web::resource("/api/me").route(get().to(me)).default_service(not_found()));
}

async fn item(id: Path<usize>) -> HttpResponse {
    reply(arena::item(id.into_inner()))
}

async fn write(id: Path<usize>, body: Result<Json<Write>, JsonPayloadError>) -> HttpResponse {
    reply(arena::write(id.into_inner(), body.is_ok()))
}

async fn me(req: HttpRequest) -> HttpResponse {
    reply(arena::me(req.headers().get("x-user-id").map(|v| v.as_bytes())))
}
