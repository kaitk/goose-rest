// The application state and its error domain, the answer type, the
// extractors, and the middleware the tiers share.

use std::cell::RefCell;
use std::future::poll_fn;
use std::marker::PhantomData;
use std::pin::Pin;
use std::rc::Rc;
use std::task::{Context, Poll};

use futures_util::{Stream, StreamExt};
use ntex::util::Bytes;
use ntex::http::body::Body;
use ntex::http::error::PayloadError;
use ntex::http::header::{AUTHORIZATION, CONTENT_LENGTH, CONTENT_TYPE, HeaderValue, ORIGIN, SERVER};
use ntex::http::{ConnectionType, HttpMessage, Payload, StatusCode};
use ntex::web::error::{JsonError, JsonPayloadError, PathError, QueryPayloadError};
use ntex::web::{self, FromRequest, HttpRequest, HttpResponse, InternalError, WebRequest, WebResponse};
use ntex::web::{WebResponseError, guard};
use ntex::{Ctx, Middleware, Service};
use ntex_cors::CorsError;
use rest_app::{Reply, Tier, arena, heavy, snow, writes};

// The application state: the tier, which picks how the error domain answers
// an extractor's error.
#[derive(Clone, Copy)]
pub struct Bench(pub Tier);

// The error domain: each error an extractor or middleware can return is
// answered as the tier's routes answer it.
pub enum Answers {}

impl web::State for Bench {
    type Error = Answers;
}

// A route's answer, with TechEmpower's ntex entry's Server field.
pub fn reply(r: Reply) -> HttpResponse {
    let Reply { status, json, close, body } = r;
    let mut res = HttpResponse::with_body(StatusCode::from_u16(status).unwrap(), Body::from(body));
    res.headers_mut().insert(SERVER, HeaderValue::from_static("N"));
    if json {
        res.headers_mut().insert(CONTENT_TYPE, HeaderValue::from_static("application/json"));
    }
    if close {
        res.head_mut().set_connection_type(ConnectionType::Close);
    }
    res
}

pub type Refused = InternalError<&'static str>;

// An extractor's error answered with r.
pub fn refuse(r: Reply) -> Refused {
    InternalError::from_response("refused", reply(r))
}

// An id that isn't a number is the tier's unknown record.
impl WebResponseError<Bench, Answers> for PathError {
    fn error_response(&self, st: &Bench) -> HttpResponse {
        reply(match st.0 {
            Tier::C | Tier::D => heavy::not_found(),
            _ => arena::not_found(),
        })
    }
}

impl WebResponseError<Bench, Answers> for QueryPayloadError {
    fn error_response(&self, st: &Bench) -> HttpResponse {
        reply(match st.0 {
            Tier::C | Tier::D => heavy::bad_request(),
            Tier::B => snow::invalid(),
            _ => Reply::empty(400),
        })
    }
}

impl WebResponseError<Bench, Answers> for JsonPayloadError {
    fn error_response(&self, _: &Bench) -> HttpResponse {
        reply(Reply::empty(if matches!(self, JsonPayloadError::Overflow) { 413 } else { 400 }))
    }
}

impl WebResponseError<Bench, Answers> for web::error::PayloadError {
    fn error_response(&self, _: &Bench) -> HttpResponse {
        reply(match self {
            web::error::PayloadError::Payload(PayloadError::Overflow) => writes::too_large(),
            _ => Reply::empty(400),
        })
    }
}

impl WebResponseError<Bench, Answers> for JsonError {
    fn error_response(&self, _: &Bench) -> HttpResponse {
        reply(Reply::empty(500))
    }
}

impl WebResponseError<Bench, Answers> for CorsError {
    fn error_response(&self, _: &Bench) -> HttpResponse {
        reply(Reply::empty(400))
    }
}

// A GET route, which HEAD takes too, as the other servers' GET routes do.
pub fn get_or_head() -> guard::AnyGuard {
    guard::Any(guard::Get()).or(guard::Head())
}

pub fn get() -> web::Route<Bench> {
    web::route().guard(get_or_head())
}

// A bearer check as middleware: tiers C's and D's on each resource, after
// its method guard, so that an unknown path or method is a 404 first; tier
// M's over every path.
#[derive(Clone, Copy)]
pub struct Bearer {
    pub valid: fn(Option<&[u8]>) -> bool,
    pub refused: fn() -> Reply,
}

pub const HEAVY_BEARER: Bearer = Bearer { valid: rest_app::has_bearer, refused: heavy::unauthorized };

pub struct BearerService<S> {
    service: S,
    bearer: Bearer,
}

impl<S, St> Middleware<S, St> for Bearer {
    type Service = BearerService<S>;

    fn create(&self, _: &St, service: S) -> Self::Service {
        BearerService { service, bearer: *self }
    }
}

impl<S, St, In> Service<St, WebRequest<In>> for BearerService<S>
where
    S: Service<St, WebRequest<In>, Res = WebResponse>,
{
    type Res = WebResponse;
    type Error = S::Error;

    ntex::forward_ready!(St, service);
    ntex::forward_shutdown!(St, service);

    async fn call(&self, req: WebRequest<In>, ctx: Ctx<'_, Self, St>) -> Result<WebResponse, S::Error> {
        if (self.bearer.valid)(req.headers().get(AUTHORIZATION).map(HeaderValue::as_bytes)) {
            ctx.call(&self.service, req).await
        } else {
            Ok(req.into_response(reply((self.bearer.refused)())))
        }
    }
}

// Tier D's body reader, as middleware on its scope: hands the handler the
// payload and, after the answer, reads what the handler and the extractors
// before it left, unless the answer is a 413 or closes the connection. ntex
// closes a connection whose payload wasn't read to its end, and the bytes
// still arriving make the close a reset, which the client can see before the
// answer. The multipart parser stops at the close delimiter, before a chunked
// body's end.
pub struct Drain;

pub struct DrainService<S> {
    service: S,
}

impl<S, St> Middleware<S, St> for Drain {
    type Service = DrainService<S>;

    fn create(&self, _: &St, service: S) -> Self::Service {
        DrainService { service }
    }
}

struct Shared(Rc<RefCell<Payload>>);

impl Stream for Shared {
    type Item = Result<Bytes, PayloadError>;

    fn poll_next(self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<Option<Self::Item>> {
        self.0.borrow_mut().poll_recv(cx)
    }
}

impl<S, St, In> Service<St, WebRequest<In>> for DrainService<S>
where
    S: Service<St, WebRequest<In>, Res = WebResponse>,
{
    type Res = WebResponse;
    type Error = S::Error;

    ntex::forward_ready!(St, service);
    ntex::forward_shutdown!(St, service);

    async fn call(&self, mut req: WebRequest<In>, ctx: Ctx<'_, Self, St>) -> Result<WebResponse, S::Error> {
        let shared = Rc::new(RefCell::new(req.take_payload()));
        req.set_payload(Payload::from_stream(Shared(shared.clone())));
        let res = ctx.call(&self.service, req).await?;
        let closes = res.status() == StatusCode::PAYLOAD_TOO_LARGE
            || res.response().head().connection_type() == ConnectionType::Close;
        if !closes {
            while let Some(Ok(_)) = poll_fn(|cx| shared.borrow_mut().poll_recv(cx)).await {}
        }
        Ok(res)
    }
}

// Tier B's writes: an Origin of the app's, or 403.
pub struct SameOrigin;

impl FromRequest<Bench> for SameOrigin {
    type Error = Refused;

    async fn from_request(_: &Bench, req: &HttpRequest, _: &mut Payload) -> Result<Self, Refused> {
        match req.headers().get(ORIGIN) {
            Some(v) if v.as_bytes() == snow::APP_URL.as_bytes() => Ok(SameOrigin),
            _ => Err(refuse(snow::cross_origin())),
        }
    }
}

// Tier B's signed-in person, by the session cookie, or 401; as an Option,
// None for no one.
pub struct Signed(pub usize);

impl FromRequest<Bench> for Signed {
    type Error = Refused;

    async fn from_request(_: &Bench, req: &HttpRequest, _: &mut Payload) -> Result<Self, Refused> {
        let person = req.cookie(snow::SESSION_COOKIE).and_then(|c| snow::person(c.value().as_bytes()));
        person.map(Signed).ok_or_else(|| refuse(snow::sign_in_required()))
    }
}

// A media type a tier D route takes.
pub trait Media {
    const TYPE: &'static str;
}

pub struct Csv;
pub struct Multipart;
pub struct Json;
pub struct Form;

impl Media for Csv {
    const TYPE: &'static str = writes::CSV;
}

impl Media for Multipart {
    const TYPE: &'static str = writes::MULTIPART;
}

impl Media for Json {
    const TYPE: &'static str = writes::JSON;
}

impl Media for Form {
    const TYPE: &'static str = writes::FORM;
}

// A Content-Type of M's media type, or 415, checked before the body is read.
pub struct ContentType<M>(PhantomData<M>);

impl<M: Media> FromRequest<Bench> for ContentType<M> {
    type Error = Refused;

    async fn from_request(_: &Bench, req: &HttpRequest, _: &mut Payload) -> Result<Self, Refused> {
        if writes::has_type(req.headers().get(CONTENT_TYPE).map(HeaderValue::as_bytes), M::TYPE) {
            Ok(ContentType(PhantomData))
        } else {
            Err(refuse(writes::unsupported_media_type()))
        }
    }
}

// Whether the request declares a body longer than limit.
pub fn declared_over(req: &HttpRequest, limit: usize) -> bool {
    writes::declared_over(req.headers().get(CONTENT_LENGTH).map(HeaderValue::as_bytes), limit)
}

// A body buffered whole, within LIMIT bytes: 413 for a declared length over
// it, before reading, or for more bytes than it, 400 for a broken stream.
// ntex's PayloadConfig is one limit for the whole application, and tier D's
// routes have two.
pub struct Limited<const LIMIT: usize>(pub Vec<u8>);

impl<const LIMIT: usize> FromRequest<Bench> for Limited<LIMIT> {
    type Error = Refused;

    async fn from_request(_: &Bench, req: &HttpRequest, payload: &mut Payload) -> Result<Self, Refused> {
        if declared_over(req, LIMIT) {
            return Err(refuse(writes::too_large()));
        }
        let mut payload = payload.take();
        let mut body = Vec::new();
        while let Some(piece) = payload.next().await {
            let data = piece.map_err(|_| refuse(writes::bad_request()))?;
            if body.len() + data.len() > LIMIT {
                return Err(refuse(writes::too_large()));
            }
            body.extend_from_slice(&data);
        }
        Ok(Limited(body))
    }
}
