// Tier D, under /api/v3, behind the bearer middleware, as tier C, and drain
// outside it, so a body an early answer leaves is read. Each route
// checks its media type (ContentType) before it reads the body, and limits
// the body with tower-http's RequestBodyLimitLayer, axum's documented way to
// refuse a declared Content-Length over the limit before reading, with
// DefaultBodyLimit off so the one limit holds. How each route reads:
//
//   imports       Body::into_data_stream, each frame into the CSV reader
//   attachments   Body::into_data_stream through multer, each part's chunks
//                 as they come
//   bookings      Bytes, the body buffered whole
//   forms         Bytes, the body buffered whole

use std::convert::Infallible;
use std::error::Error;

use axum::Router;
use axum::body::{Body, Bytes};
use axum::extract::DefaultBodyLimit;
use axum::extract::rejection::BytesRejection;
use axum::http::StatusCode;
use axum::middleware;
use axum::routing::{MethodRouter, post};
use futures_util::StreamExt;
use http_body_util::LengthLimitError;
use rest_app::Reply;
use rest_app::writes::{self, Attachment, Import};
use tower_http::limit::RequestBodyLimitLayer;

use crate::extract::{self as ex, ContentType, R, bearer, drain};

pub fn routes() -> Router {
    // route_layer's drain doesn't reach the fallbacks, so they read the body
    // themselves before the 404.
    let not_found = |body: Body| async move {
        let mut stream = body.into_data_stream();
        while let Some(Ok(_)) = stream.next().await {}
        R(writes::not_found())
    };
    let limited = |route: MethodRouter, limit: usize| -> MethodRouter {
        route.layer::<_, Infallible>(DefaultBodyLimit::disable()).layer(RequestBodyLimitLayer::new(limit))
    };
    let v3 = Router::new()
        .route("/imports", limited(post(imports), writes::IMPORT_LIMIT))
        .route("/attachments", limited(post(attachments), writes::ATTACHMENT_LIMIT))
        .route("/bookings/batch", limited(post(batch), writes::BATCH_LIMIT))
        .route("/forms", limited(post(form), writes::FORM_LIMIT))
        .route_layer(middleware::from_fn(bearer))
        .route_layer(middleware::from_fn(drain))
        .method_not_allowed_fallback(not_found)
        .fallback(not_found);
    Router::new().nest("/api/v3", v3)
}

// Whether a body's error is its limit's.
fn over_limit(e: &(dyn Error + 'static)) -> bool {
    let mut at = Some(e);
    while let Some(e) = at {
        if e.is::<LengthLimitError>() {
            return true;
        }
        at = e.source();
    }
    false
}

async fn imports(_: ContentType<ex::Csv>, body: Body) -> R {
    let mut import = Import::default();
    let mut stream = body.into_data_stream();
    while let Some(piece) = stream.next().await {
        let pushed = match piece {
            Ok(data) => import.push(&data),
            Err(e) => Err(if over_limit(&e) { writes::too_large() } else { writes::bad_request() }),
        };
        if let Err(r) = pushed {
            return R(r);
        }
    }
    R(import.finish())
}

fn multipart_error(e: multer::Error) -> Reply {
    if over_limit(&e) { writes::too_large() } else { writes::bad_request() }
}

async fn read_parts(parts: &mut multer::Multipart<'_>) -> Reply {
    let mut a = Attachment::default();
    loop {
        let mut field = match parts.next_field().await {
            Ok(Some(f)) => f,
            Ok(None) => break,
            Err(e) => return multipart_error(e),
        };
        let ctype = field.content_type().map(ToString::to_string);
        if let Err(r) = a.begin(field.name(), field.file_name(), ctype.as_deref()) {
            return r;
        }
        loop {
            match field.chunk().await {
                Ok(Some(data)) => {
                    if let Err(r) = a.push(&data) {
                        return r;
                    }
                }
                Ok(None) => break,
                Err(e) => return multipart_error(e),
            }
        }
    }
    a.finish()
}

// multer, the parser axum's Multipart wraps, on the body's stream, which
// drain reads to its end after the close delimiter.
async fn attachments(ContentType(ctype, _): ContentType<ex::Multipart>, body: Body) -> R {
    R(match multer::parse_boundary(ctype.to_str().unwrap_or("")) {
        Ok(boundary) => read_parts(&mut multer::Multipart::new(body.into_data_stream(), boundary)).await,
        Err(_) => writes::bad_request(),
    })
}

fn whole(body: Result<Bytes, BytesRejection>, answer: fn(&[u8]) -> Reply) -> R {
    R(match body {
        Ok(b) => answer(&b),
        Err(e) if e.status() == StatusCode::PAYLOAD_TOO_LARGE => writes::too_large(),
        Err(_) => writes::bad_request(),
    })
}

async fn batch(_: ContentType<ex::Json>, body: Result<Bytes, BytesRejection>) -> R {
    whole(body, writes::batch)
}

async fn form(_: ContentType<ex::Form>, body: Result<Bytes, BytesRejection>) -> R {
    whole(body, writes::form)
}
