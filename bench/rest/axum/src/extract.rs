// The answer type, the extractors, and the middleware the tiers share.

use std::marker::PhantomData;
use std::pin::Pin;
use std::sync::{Arc, Mutex};
use std::task::{Context, Poll};

use axum::body::{Body, BodyDataStream, Bytes};
use futures_util::{Stream, StreamExt};
use axum::extract::{FromRequestParts, OptionalFromRequestParts, Request};
use axum::http::header::{AUTHORIZATION, CONNECTION, CONTENT_TYPE, ORIGIN};
use axum::http::request::Parts;
use axum::http::{HeaderValue, StatusCode};
use axum::middleware::Next;
use axum::response::{IntoResponse, Response};
use axum_extra::extract::CookieJar;
use rest_app::{heavy, snow, writes, Reply};

static APPLICATION_JSON: HeaderValue = HeaderValue::from_static("application/json");
static CLOSE: HeaderValue = HeaderValue::from_static("close");

// A route's answer.
pub struct R(pub Reply);

impl IntoResponse for R {
    fn into_response(self) -> Response {
        let Reply { status, json, close, body } = self.0;
        let mut res = Response::new(Body::from(body));
        *res.status_mut() = StatusCode::from_u16(status).unwrap();
        if json {
            res.headers_mut().insert(CONTENT_TYPE, APPLICATION_JSON.clone());
        }
        if close {
            res.headers_mut().insert(CONNECTION, CLOSE.clone());
        }
        res
    }
}

// Tiers C's and D's bearer token, over the routes of a tier's router
// (Router::route_layer), so that an unknown path is a 404 first.
pub async fn bearer(req: Request, next: Next) -> Response {
    if rest_app::has_bearer(req.headers().get(AUTHORIZATION).map(HeaderValue::as_bytes)) {
        next.run(req).await
    } else {
        R(heavy::unauthorized()).into_response()
    }
}

// The request body's stream, shared between the handler and drain.
struct Shared(Arc<Mutex<BodyDataStream>>);

impl Stream for Shared {
    type Item = Result<Bytes, axum::Error>;

    fn poll_next(self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<Option<Self::Item>> {
        self.0.lock().unwrap().poll_next_unpin(cx)
    }
}

// hyper closes a kept-alive connection whose request body wasn't read to its
// end when the answer went out, without Connection: close, unless the rest
// had already arrived; the client's next request on it then fails. On the
// routes that take a body, this reads what the handler and the extractors
// before it left, as goose-http's Rust routes do, unless the answer is a
// 413 or closes the connection.
pub async fn drain(req: Request, next: Next) -> Response {
    let (parts, body) = req.into_parts();
    let shared = Arc::new(Mutex::new(body.into_data_stream()));
    let res = next.run(Request::from_parts(parts, Body::from_stream(Shared(shared.clone())))).await;
    let closes = res.status() == StatusCode::PAYLOAD_TOO_LARGE || res.headers().get(CONNECTION) == Some(&CLOSE);
    if let (false, Ok(stream)) = (closes, Arc::try_unwrap(shared)) {
        let mut stream = stream.into_inner().unwrap();
        while let Some(Ok(_)) = stream.next().await {}
    }
    res
}

// Tier A's X-User-Id.
pub struct UserId(pub Option<HeaderValue>);

impl<S: Send + Sync> FromRequestParts<S> for UserId {
    type Rejection = std::convert::Infallible;

    async fn from_request_parts(parts: &mut Parts, _: &S) -> Result<Self, Self::Rejection> {
        Ok(UserId(parts.headers.get("x-user-id").cloned()))
    }
}

// Tier B's writes: an Origin of the app's, or 403.
pub struct SameOrigin;

impl<S: Send + Sync> FromRequestParts<S> for SameOrigin {
    type Rejection = R;

    async fn from_request_parts(parts: &mut Parts, _: &S) -> Result<Self, Self::Rejection> {
        match parts.headers.get(ORIGIN) {
            Some(v) if v.as_bytes() == snow::APP_URL.as_bytes() => Ok(SameOrigin),
            _ => Err(R(snow::cross_origin())),
        }
    }
}

// Tier B's signed-in person, by the session cookie, or 401; as an Option,
// None for no one.
pub struct Signed(pub usize);

impl<S: Send + Sync> OptionalFromRequestParts<S> for Signed {
    type Rejection = std::convert::Infallible;

    async fn from_request_parts(parts: &mut Parts, _: &S) -> Result<Option<Self>, Self::Rejection> {
        let jar = CookieJar::from_headers(&parts.headers);
        Ok(jar.get(snow::SESSION_COOKIE).and_then(|c| snow::person(c.value_trimmed().as_bytes())).map(Signed))
    }
}

impl<S: Send + Sync> FromRequestParts<S> for Signed {
    type Rejection = R;

    async fn from_request_parts(parts: &mut Parts, state: &S) -> Result<Self, Self::Rejection> {
        let signed = <Signed as OptionalFromRequestParts<S>>::from_request_parts(parts, state).await;
        signed.ok().flatten().ok_or(R(snow::sign_in_required()))
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
pub struct ContentType<M>(pub HeaderValue, pub PhantomData<M>);

impl<S: Send + Sync, M: Media> FromRequestParts<S> for ContentType<M> {
    type Rejection = R;

    async fn from_request_parts(parts: &mut Parts, _: &S) -> Result<Self, Self::Rejection> {
        match parts.headers.get(CONTENT_TYPE) {
            Some(v) if writes::has_type(Some(v.as_bytes()), M::TYPE) => Ok(ContentType(v.clone(), PhantomData)),
            _ => Err(R(writes::unsupported_media_type())),
        }
    }
}
