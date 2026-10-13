// Tier A. An id that isn't a number is Path's rejection, answered 404 as an
// unknown id is; a body that isn't a Write is Json's rejection, answered 422.

use axum::Router;
use axum::extract::rejection::{JsonRejection, PathRejection};
use axum::extract::{Json, Path};
use axum::middleware;
use axum::routing::{get, post};
use rest_app::arena::{self, Write};

use crate::extract::{R, UserId, drain};

pub fn routes() -> Router {
    Router::new()
        .route("/api/items/{id}", get(item).merge(post(write).layer(middleware::from_fn(drain))))
        .route("/api/me", get(me))
        .method_not_allowed_fallback(|| async { R(arena::not_found()) })
}

async fn item(id: Result<Path<usize>, PathRejection>) -> R {
    R(match id {
        Ok(Path(id)) => arena::item(id),
        Err(_) => arena::not_found(),
    })
}

async fn write(id: Result<Path<usize>, PathRejection>, body: Result<Json<Write>, JsonRejection>) -> R {
    R(match id {
        Ok(Path(id)) => arena::write(id, body.is_ok()),
        Err(_) => arena::not_found(),
    })
}

async fn me(UserId(user): UserId) -> R {
    R(arena::me(user.as_ref().map(|v| v.as_bytes())))
}
