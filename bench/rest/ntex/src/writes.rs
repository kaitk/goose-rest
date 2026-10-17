// Tier D, the scope /api/v3, each resource behind the bearer middleware, as
// tier C, and the scope behind Drain, which reads what an answer leaves of a
// body. Each route checks its media type (ContentType) before it reads the
// body. How each route reads, and how its limit holds:
//
//   imports       web::types::Payload, each chunk into the CSV reader; a
//                 declared length over the limit is refused before reading,
//                 and the reader counts the rest
//   attachments   the payload through ntex-multipart's Multipart, each
//                 field's chunks as they come; limited as imports, with the
//                 payload counted on its way into Multipart
//   bookings      Limited, buffered whole within the route's limit
//   forms         Limited, as bookings

use std::pin::Pin;
use std::task::{Context, Poll};

use futures_util::{Stream, StreamExt};
use ntex::http::error::PayloadError;
use ntex::util::{Bytes, BytesMut};
use ntex::web::types::Payload;
use ntex::web::{self, HttpRequest, HttpResponse, ServiceConfig, guard};
use ntex_multipart::MultipartError;
use rest_app::Reply;
use rest_app::writes::{self, Attachment, Import};

use crate::extract::{self as ex, Bench, ContentType, Drain, HEAVY_BEARER, Limited, declared_over, reply};

pub fn routes(cfg: &mut ServiceConfig<Bench>) {
    let resource = |path: &str| web::resource(path).guard(guard::Post()).middleware(HEAVY_BEARER);
    cfg.service(web::scope("/api/v3")
                    .middleware(Drain)
                    .service(resource("/imports").to(imports))
                    .service(resource("/attachments").to(attachments))
                    .service(resource("/bookings/batch").to(batch))
                    .service(resource("/forms").to(form))
                    .default_service(web::to(async || reply(writes::not_found()))));
}

async fn imports(_: ContentType<ex::Csv>, req: HttpRequest, mut payload: Payload) -> HttpResponse {
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

// The longest delimiter, "\r\n--" and a boundary of up to 70 characters (RFC
// 2046).
const DELIMITER: usize = 4 + 70;

// A body for ntex-multipart 4.1.0, each piece ending at least a delimiter's
// length past its last '\r', the rest held until more arrives or the body
// ends. Its field reader takes a buffer of exactly "\r\n--" for field data,
// where the boundary might follow, so a body arriving in small pieces lost its
// close delimiter now and then.
struct Delimited<S> {
    stream: S,
    held: BytesMut,
    done: bool,
}

impl<S> Delimited<S> {
    fn new(stream: S) -> Self {
        Delimited { stream, held: BytesMut::new(), done: false }
    }
}

impl<S: Stream<Item = Result<Bytes, PayloadError>> + Unpin> Stream for Delimited<S> {
    type Item = Result<Bytes, PayloadError>;

    fn poll_next(mut self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<Option<Self::Item>> {
        loop {
            if self.done {
                return Poll::Ready((!self.held.is_empty()).then(|| Ok(self.held.take())));
            }
            match Pin::new(&mut self.stream).poll_next(cx) {
                Poll::Ready(Some(Ok(data))) => {
                    self.held.extend_from_slice(&data);
                    let n = self.held.len();
                    let keep = match self.held.iter().rposition(|&c| c == b'\r') {
                        Some(i) if n - i < DELIMITER => n - i,
                        _ => 0,
                    };
                    if n > keep {
                        return Poll::Ready(Some(Ok(self.held.split_to(n - keep))));
                    }
                }
                Poll::Ready(Some(Err(e))) => return Poll::Ready(Some(Err(e))),
                Poll::Ready(None) => self.done = true,
                Poll::Pending => return Poll::Pending,
            }
        }
    }
}

fn multipart_error(e: MultipartError) -> Reply {
    match e {
        MultipartError::Payload(PayloadError::Overflow) => writes::too_large(),
        _ => writes::bad_request(),
    }
}

async fn attachments(_: ContentType<ex::Multipart>, req: HttpRequest, payload: Payload) -> HttpResponse {
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
    let mut parts = ntex_multipart::Multipart::new(req.headers(), Delimited::new(Box::pin(counted)));
    let mut a = Attachment::default();
    while let Some(field) = parts.next().await {
        let mut field = match field {
            Ok(f) => f,
            Err(e) => return reply(multipart_error(e)),
        };
        let ctype = field.content_type().map(ToString::to_string);
        let filename = field.content_disposition().and_then(|cd| cd.get_filename()).map(ToString::to_string);
        if let Err(r) = a.begin(field.name(), filename.as_deref(), ctype.as_deref()) {
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

async fn batch(_: ContentType<ex::Json>, Limited(body): Limited<{ writes::BATCH_LIMIT }>) -> HttpResponse {
    reply(writes::batch(&body))
}

async fn form(_: ContentType<ex::Form>, Limited(body): Limited<{ writes::FORM_LIMIT }>) -> HttpResponse {
    reply(writes::form(&body))
}
