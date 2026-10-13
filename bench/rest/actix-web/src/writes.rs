// Tier D, the scope /api/v3, each route behind the bearer middleware, as tier
// C. Each route checks its media type (ContentType) before it reads the body.
// How each route reads, and how its limit holds:
//
//   imports       web::Payload, each chunk into the CSV reader; a declared
//                 length over the limit is refused before reading, and the
//                 reader counts the rest
//   attachments   web::Payload through actix-multipart's Multipart, each
//                 field's chunks as they come; limited as imports, with the
//                 payload counted on its way into Multipart
//   bookings      web::Bytes, buffered whole, within the resource's
//                 PayloadConfig limit
//   forms         web::Bytes, as bookings
//
// actix-web's PayloadConfig limits only the buffering extractors, and
// actix-multipart's MultipartConfig only its in-memory buffer, so the streamed
// routes keep their limits by hand. An answer before a body's end leaves the
// rest to actix-http, which drains a chunked body and closes the connection
// after a sized one, saying so in Connection.

use actix_web::error::PayloadError;
use actix_web::http::header::CONTENT_LENGTH;
use actix_web::middleware::from_fn;
use actix_web::web::{self, Bytes, ServiceConfig};
use actix_web::{Error, HttpRequest, HttpResponse};
use futures_util::StreamExt;
use rest_app::Reply;
use rest_app::writes::{self, Attachment, Import};

use crate::extract::{self as ex, ContentType, bearer, reply};

pub fn routes(cfg: &mut ServiceConfig) {
    let not_found = || web::to(|| async { reply(writes::not_found()) });
    let resource = |path: &str| web::resource(path).default_service(not_found());
    cfg.service(web::scope("/api/v3")
                    .service(resource("/imports").route(web::post().to(imports).wrap(from_fn(bearer))))
                    .service(resource("/attachments").route(web::post().to(attachments).wrap(from_fn(bearer))))
                    .service(resource("/bookings/batch")
                                 .app_data(web::PayloadConfig::new(writes::BATCH_LIMIT))
                                 .route(web::post().to(batch).wrap(from_fn(bearer))))
                    .service(resource("/forms")
                                 .app_data(web::PayloadConfig::new(writes::FORM_LIMIT))
                                 .route(web::post().to(form).wrap(from_fn(bearer))))
                    .default_service(not_found()));
}

fn declared_over(req: &HttpRequest, limit: usize) -> bool {
    writes::declared_over(req.headers().get(CONTENT_LENGTH).map(|v| v.as_bytes()), limit)
}

async fn imports(_: ContentType<ex::Csv>, req: HttpRequest, mut payload: web::Payload) -> HttpResponse<Bytes> {
    if declared_over(&req, writes::IMPORT_LIMIT) {
        return reply(writes::too_large());
    }
    let mut import = Import::default();
    while let Some(piece) = payload.next().await {
        let pushed = match piece {
            Ok(data) => import.push(&data),
            Err(_) => Err(writes::bad_request()),
        };
        if let Err(r) = pushed {
            return reply(r);
        }
    }
    reply(import.finish())
}

fn multipart_error(e: actix_multipart::MultipartError) -> Reply {
    match e {
        actix_multipart::MultipartError::Payload(PayloadError::Overflow) => writes::too_large(),
        _ => writes::bad_request(),
    }
}

async fn attachments(_: ContentType<ex::Multipart>, req: HttpRequest, payload: web::Payload) -> HttpResponse<Bytes> {
    if declared_over(&req, writes::ATTACHMENT_LIMIT) {
        return reply(writes::too_large());
    }
    let counted = payload.scan(0usize, |taken, piece| {
        let piece = piece.and_then(|data| {
            *taken += data.len();
            if *taken > writes::ATTACHMENT_LIMIT { Err(PayloadError::Overflow) } else { Ok(data) }
        });
        std::future::ready(Some(piece))
    });
    let mut parts = actix_multipart::Multipart::new(req.headers(), counted);
    let mut a = Attachment::default();
    while let Some(field) = parts.next().await {
        let mut field = match field {
            Ok(f) => f,
            Err(e) => return reply(multipart_error(e)),
        };
        let ctype = field.content_type().map(ToString::to_string);
        let filename = field.content_disposition().and_then(|cd| cd.get_filename());
        if let Err(r) = a.begin(field.name(), filename, ctype.as_deref()) {
            return reply(r);
        }
        while let Some(chunk) = field.next().await {
            let pushed = match chunk {
                Ok(data) => a.push(&data),
                Err(e) => Err(multipart_error(e)),
            };
            if let Err(r) = pushed {
                return reply(r);
            }
        }
    }
    reply(a.finish())
}

fn whole(body: Result<Bytes, Error>, answer: fn(&[u8]) -> Reply) -> HttpResponse<Bytes> {
    reply(match body {
        Ok(b) => answer(&b),
        Err(e) if e.as_error::<PayloadError>().is_some_and(|p| matches!(p, PayloadError::Overflow)) => {
            writes::too_large()
        }
        Err(_) => writes::bad_request(),
    })
}

async fn batch(_: ContentType<ex::Json>, body: Result<Bytes, Error>) -> HttpResponse<Bytes> {
    whole(body, writes::batch)
}

async fn form(_: ContentType<ex::Form>, body: Result<Bytes, Error>) -> HttpResponse<Bytes> {
    whole(body, writes::form)
}
