// plod::serve and plod::serve_epoll with HTTP/3 too, on the listeners with h3
// (http::Listener.h3), with goose-http's http.h3 beside http.tls. HTTP/3 needs
// TLS on the same listener, and costs more per request than h2, so it's served
// only where a program imports this module and a listener asks:
//
//   import http from "github.com/kaitk/goose-http@v0.5.8";
//   import tls from "github.com/kaitk/goose-tls@v0.0.5";
//   import plod from "github.com/kaitk/plod@<tag>";
//   import plod.h3;
namespace plod;

import std;
import http from "github.com/kaitk/goose-http@v0.5.8";
import tls from "github.com/kaitk/goose-tls@v0.0.5";
import http.tls;
import http.h3;

// A worker's HTTP/3 server for serve with state that starts as fresh, on its
// own reference to ctx, whose ALPN protocols must list "h3". http::release
// frees it once serve has returned.
fn h3_server<S>(ctx: tls::Context, fresh: S) -> http::H3ServerOf<Slot<S>> {
    return http::h3_server(ctx, Slot<S> { state: fresh });
}

// serve, with TLS as plod.tls's serve gives it, and HTTP/3 with h3 on the
// listeners with h3. Its block repeats serve's.
//
//   var server = http::tls_server(ctx);
//   var h3 = plod::h3_server(ctx, St { .. });
//   plod::serve(cfg, app, St { .. }, server, h3) { cx => handle(cx) };
//   http::release(h3);
//   http::release(server);
fn serve<A, S, C, H>(cfg: http::Config, app: A&, fresh: S, server: http::TlsServerOf<C>&,
                     h3: http::H3ServerOf<Slot<S>>&) -> http::Error {
    return http::serve(cfg, Slot<S> { state: fresh }, server, h3) { ev, st, out =>
        let mark = on_event(ev, st, app, out) { cx => H(cx) };
        if (st.ex.mode & LATER) != 0 { on_later(ev, st, app, out, mark) { cx => H(cx) }; }
    };
}

// serve with TLS and HTTP/3 on goose-http's epoll loop.
fn serve_epoll<A, S, C, H>(cfg: http::Config, app: A&, fresh: S, server: http::TlsServerOf<C>&,
                           h3: http::H3ServerOf<Slot<S>>&) -> http::Error {
    return http::serve_epoll(cfg, Slot<S> { state: fresh }, server, h3) { ev, st, out =>
        let mark = on_event(ev, st, app, out) { cx => H(cx) };
        if (st.ex.mode & LATER) != 0 { on_later(ev, st, app, out, mark) { cx => H(cx) }; }
    };
}
