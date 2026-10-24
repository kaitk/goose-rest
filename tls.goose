// plod::serve and plod::serve_epoll with HTTPS on the listeners that ask for
// it, with goose-http's http.tls. Only a program that imports this module
// needs goose-tls, which its root file declares at the tag goose-http's
// tls.goose names:
//
//   import http from "github.com/kaitk/goose-http@v0.5.9";
//   import tls from "github.com/kaitk/goose-tls@v0.0.5";
//   import plod from "github.com/kaitk/plod@<tag>";
//   import plod.tls;
namespace plod;

import std;
import http from "github.com/kaitk/goose-http@v0.5.9";
import tls from "github.com/kaitk/goose-tls@v0.0.5";
import http.tls;

// serve, whose listeners with tls (http::Listener.tls, or Config.tls for
// Config.port's) serve TLS with server, the worker's http::TlsServer, or
// http::TlsServerOf<C> with a chooser (http::tls_server(ctx, chooser)), which
// http::release frees once serve has returned: h2 where the context lists
// "h2" and the client chose it, HTTP/1.1 otherwise.
// Its block repeats serve's, as serve_epoll's does.
//
//   var server = http::tls_server(ctx);
//   plod::serve(cfg, app, St { .. }, server) { cx => handle(cx) };
//   http::release(server);
fn serve<A, S, C, H>(cfg: http::Config, app: A&, fresh: S, server: http::TlsServerOf<C>&) -> http::Error {
    return http::serve(cfg, Slot<S> { state: fresh }, server) { ev, st, out =>
        let mark = on_event(ev, st, app, out) { cx => H(cx) };
        if (st.ex.mode & LATER) != 0 { on_later(ev, st, app, out, mark) { cx => H(cx) }; }
    };
}

// serve with TLS on goose-http's epoll loop.
fn serve_epoll<A, S, C, H>(cfg: http::Config, app: A&, fresh: S, server: http::TlsServerOf<C>&) -> http::Error {
    return http::serve_epoll(cfg, Slot<S> { state: fresh }, server) { ev, st, out =>
        let mark = on_event(ev, st, app, out) { cx => H(cx) };
        if (st.ex.mode & LATER) != 0 { on_later(ev, st, app, out, mark) { cx => H(cx) }; }
    };
}
