// Tier A. An id that isn't a number is Path's error, answered 404 by
// PathConfig's handler as an unknown id is; a body that isn't a Write is
// Json's error, answered 422 after the id is looked up. A method a resource
// lacks answers 404, as an unknown path does.

use actix_web::web::{self, Bytes, ServiceConfig};
use actix_web::{Error, HttpRequest, HttpResponse};
use rest_app::arena::{self, Write};

use crate::extract::{get, refuse, reply};

pub fn routes(cfg: &mut ServiceConfig) {
    let not_found = || web::to(|| async { reply(arena::not_found()) });
    let path = web::PathConfig::default().error_handler(|_, _| refuse(arena::not_found()));
    cfg.service(web::resource("/api/items/{id}")
                    .app_data(path)
                    .route(get().to(item))
                    .route(web::post().to(write))
                    .default_service(not_found()))
        .service(web::resource("/api/me").route(get().to(me)).default_service(not_found()));
}

async fn item(id: web::Path<usize>) -> HttpResponse<Bytes> {
    reply(arena::item(id.into_inner()))
}

async fn write(id: web::Path<usize>, body: Result<web::Json<Write>, Error>) -> HttpResponse<Bytes> {
    reply(arena::write(id.into_inner(), body.is_ok()))
}

async fn me(req: HttpRequest) -> HttpResponse<Bytes> {
    reply(arena::me(req.headers().get("x-user-id").map(|v| v.as_bytes())))
}
