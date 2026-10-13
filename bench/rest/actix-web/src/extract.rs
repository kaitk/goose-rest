// The answer type, the extractors, the middleware, and the extractor error
// handlers the tiers share.

use std::future::{Ready, ready};
use std::marker::PhantomData;

use actix_http::ConnectionType;
use actix_web::body::{BoxBody, EitherBody, MessageBody};
use actix_web::dev::{Payload, ServiceRequest, ServiceResponse};
use actix_web::error::InternalError;
use actix_web::http::StatusCode;
use actix_web::http::header::{AUTHORIZATION, CONTENT_TYPE, HeaderValue, ORIGIN, SERVER};
use actix_web::middleware::Next;
use actix_web::web::{self, Bytes};
use actix_web::{Error, FromRequest, HttpRequest, HttpResponse, Route, guard};
use rest_app::{Reply, heavy, snow, writes};

// A route's answer, with TechEmpower's actix entry's Server field.
pub fn reply(r: Reply) -> HttpResponse<Bytes> {
    let Reply { status, json, close, body } = r;
    let mut res = HttpResponse::with_body(StatusCode::from_u16(status).unwrap(), Bytes::from(body));
    res.headers_mut().insert(SERVER, HeaderValue::from_static("A"));
    if json {
        res.headers_mut().insert(CONTENT_TYPE, HeaderValue::from_static("application/json"));
    }
    if close {
        res.head_mut().set_connection_type(ConnectionType::Close);
    }
    res
}

// An extractor's error answered with r.
pub fn refuse(r: Reply) -> Error {
    InternalError::from_response("refused", reply(r).map_into_boxed_body()).into()
}

// A GET route, which HEAD takes too, as the other servers' GET routes do.
pub fn get() -> Route {
    web::route().guard(guard::Any(guard::Get()).or(guard::Head()))
}

// Tiers C's and D's bearer token, on each route (Route::wrap), so that an
// unknown path or method is a 404 first.
pub async fn bearer(req: ServiceRequest, next: Next<impl MessageBody + 'static>)
                    -> Result<ServiceResponse<EitherBody<impl MessageBody, BoxBody>>, Error> {
    if rest_app::has_bearer(req.headers().get(AUTHORIZATION).map(HeaderValue::as_bytes)) {
        next.call(req).await.map(ServiceResponse::map_into_left_body)
    } else {
        Ok(req.into_response(reply(heavy::unauthorized()).map_into_boxed_body()).map_into_right_body())
    }
}

// Tier B's writes: an Origin of the app's, or 403.
pub struct SameOrigin;

impl FromRequest for SameOrigin {
    type Error = Error;
    type Future = Ready<Result<Self, Error>>;

    fn from_request(req: &HttpRequest, _: &mut Payload) -> Self::Future {
        ready(match req.headers().get(ORIGIN) {
            Some(v) if v.as_bytes() == snow::APP_URL.as_bytes() => Ok(SameOrigin),
            _ => Err(refuse(snow::cross_origin())),
        })
    }
}

// Tier B's signed-in person, by the session cookie, or 401; as an Option,
// None for no one.
pub struct Signed(pub usize);

impl FromRequest for Signed {
    type Error = Error;
    type Future = Ready<Result<Self, Error>>;

    fn from_request(req: &HttpRequest, _: &mut Payload) -> Self::Future {
        let person = req.cookie(snow::SESSION_COOKIE).and_then(|c| snow::person(c.value().as_bytes()));
        ready(person.map(Signed).ok_or_else(|| refuse(snow::sign_in_required())))
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

impl<M: Media> FromRequest for ContentType<M> {
    type Error = Error;
    type Future = Ready<Result<Self, Error>>;

    fn from_request(req: &HttpRequest, _: &mut Payload) -> Self::Future {
        ready(if writes::has_type(req.headers().get(CONTENT_TYPE).map(HeaderValue::as_bytes), M::TYPE) {
            Ok(ContentType(PhantomData))
        } else {
            Err(refuse(writes::unsupported_media_type()))
        })
    }
}
