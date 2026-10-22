// rest::serve and rest::serve_epoll with HTTPS on the listeners that ask for
// it, with goose-http's http.tls. Only a program that imports this module
// needs goose-tls, which its root file declares at the tag goose-http's
// tls.goose names:
//
//   import http from "github.com/kaitk/goose-http@e128cb39d82c0fa45280452b1c434a55384e14d7";
//   import tls from "github.com/kaitk/goose-tls@v0.0.3";
//   import rest from "github.com/kaitk/goose-rest@<tag>";
//   import rest.tls;
namespace rest;

import std;
import http from "github.com/kaitk/goose-http@e128cb39d82c0fa45280452b1c434a55384e14d7";
import tls from "github.com/kaitk/goose-tls@v0.0.3";
import http.tls;

// serve, whose listeners with tls (http::Listener.tls, or Config.tls for
// Config.port's) serve HTTP/1.1 over TLS with server, the worker's
// http::TlsServer, which http::release frees once serve has returned.
// Its block repeats serve's, as serve_epoll's does.
//
//   var server = http::tls_server(ctx);
//   rest::serve(cfg, app, St { .. }, server) { cx => handle(cx) };
//   http::release(server);
fn serve<A, S, H>(cfg: http::Config, app: A&, fresh: S, server: http::TlsServer&) -> http::Error {
    return http::serve(cfg, Slot<S> { state: fresh }, server) { ev, st, out =>
        let mark = on_event(ev, st, app, out) { cx => H(cx) };
        if (st.ex.mode & LATER) != 0 { on_later(ev, st, app, out, mark) { cx => H(cx) }; }
    };
}

// serve with TLS on goose-http's epoll loop, which on Linux can hand a
// connection's records to the kernel (tls::use_kernel).
fn serve_epoll<A, S, H>(cfg: http::Config, app: A&, fresh: S, server: http::TlsServer&) -> http::Error {
    return http::serve_epoll(cfg, Slot<S> { state: fresh }, server) { ev, st, out =>
        let mark = on_event(ev, st, app, out) { cx => H(cx) };
        if (st.ex.mode & LATER) != 0 { on_later(ev, st, app, out, mark) { cx => H(cx) }; }
    };
}
