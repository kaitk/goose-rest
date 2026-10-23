// plod::serve and plod::serve_epoll with a chooser, each on a Unix socket in
// TMPDIR: a client sending acme.test in SNI and offering acme-tls/1 gets a
// second context, with a certificate of its own, as ACME's TLS-ALPN-01 needs;
// every other client keeps the server's context and its routes. The clients
// are goose-tls's, each trusting the one certificate it should get.
import std;
import os;
import http from "github.com/kaitk/goose-http@v0.5.6";
import tls from "github.com/kaitk/goose-tls@v0.0.5";
import plod from "../../";
import plod.tls;

struct Chooser { challenge: tls::Context }

fn http::tls_hello(c: Chooser&, conn: tls::Conn) {
    if tls::server_name(conn) == "acme.test" && tls::offers(conn, "acme-tls/1") {
        tls::use_context(conn, c.challenge);
    }
}

fn handle(cx) {
    plod::routes(cx) { cx =>
        plod::get(cx, "/") { plod::text(cx, 200, "served"); };
    };
}

thread_fn ring_worker(cfg: http::Config, ctx: tls::Context, c: Chooser) {
    var server = http::tls_server(ctx, c);
    var app = plod::NoState { .. };
    let e = plod::serve(cfg, app, false, server) { cx => handle(cx); };
    http::release(server);
    if e.code != 0 { http::report(e); }
}

thread_fn epoll_worker(cfg: http::Config, ctx: tls::Context, c: Chooser) {
    var server = http::tls_server(ctx, c);
    var app = plod::NoState { .. };
    let e = plod::serve_epoll(cfg, app, false, server) { cx => handle(cx); };
    http::release(server);
    if e.code != 0 { http::report(e); }
}

fn unix_address(name: const u8[:]) -> u8[>..] {
    var dir: u8[>..] = [];
    var a: u8[>..] = [];
    if env("TMPDIR", dir) && dir.len > 0 { format(a, "unix:", dir, "/", name); }
    else { format(a, "unix:", name); }
    return a;
}

// Sends what c has to send on s.
fn flush(s: http::Socket, c: tls::Conn) {
    var buf: u8[16384] = [0; 16384];
    loop {
        let n = tls::drain(c, buf);
        guard n > 0 else { break; }
        assert(http::send_all(s, buf[..n], 5000).code == 0);
    }
}

// Connects to address as host, offering protocols and trusting only chain,
// and prints which certificate and protocol the server answered with, and,
// for HTTP/1.1, the status line of its answer to a request.
fn client(address: const u8[:], host: const u8[:], protocols: const u8[:][:], chain: const u8[:],
          normal: const u8[:]) {
    let ctx, ok = tls::client_trusting(chain, protocols);
    assert(ok);
    var s = http::Socket { .. };
    for i in 500 {
        let t, e = http::connect(address, 0, 1000);
        if e.code == 0 {
            s = t;
            break;
        }
        sleep_ms(10);
    }
    assert(s.fd >= 0);
    let c = tls::connect(ctx, host);
    var wire: u8[16384] = [0; 16384];
    var r = 0;
    loop {
        r = tls::handshake(c);
        flush(s, c);
        guard r == tls::WANT_INPUT else { break; }
        let n = http::recv(s, wire, 5000);
        guard n > 0 else { break; }
        tls::feed(c, wire[..n]);
    }
    print("  ", host, " offering ", protocols[0], ":");
    if r != 0 {
        tls::error_text();
        print("    refused");
    } else {
        let cert = if tls::peer_certificate(c) == normal { "the server's" } else { "the challenge's" };
        print("    ", cert, " certificate, ALPN '", tls::alpn(c), "'");
    }
    if r == 0 && tls::alpn(c) == "http/1.1" {
        let req = "GET / HTTP/1.1\r\nHost: x\r\nConnection: close\r\n\r\n";
        assert(tls::write(c, req) == req.len);
        flush(s, c);
        var got: u8[>..] = [];
        var plain: u8[16384] = [0; 16384];
        loop {
            let n = tls::read(c, plain);
            if n > 0 {
                got.append(plain[..n]);
                continue;
            }
            guard n == tls::WANT_INPUT else { break; }
            let m = http::recv(s, wire, 5000);
            guard m > 0 else { break; }
            tls::feed(c, wire[..m]);
        }
        let end = find(got, "\r\n");
        print("    ", if end < 0 { got[..0] } else { got[..end] });
    }
    tls::free(c);
    tls::free(ctx);
    http::hangup(s);
}

fn clients(address: const u8[:], normal: const u8[:], challenge: const u8[:]) {
    client(address, "acme.test", ["acme-tls/1"], challenge, normal);
    client(address, "acme.test", ["http/1.1"], normal, normal);
    client(address, "localhost", ["acme-tls/1"], normal, normal);
    client(address, "localhost", ["h2", "http/1.1"], normal, normal);
    client(address, "localhost", ["http/1.1"], normal, normal);
}

fn main() {
    var normal: u8[>..] = [];
    var normal_key: u8[>..] = [];
    var challenge: u8[>..] = [];
    var challenge_key: u8[>..] = [];
    let failed = tls::run() {
        let k = tls::key_generate(tls::P256);
        normal = tls::self_signed(k, ["localhost", "acme.test"], 1);
        normal_key = tls::key_pem(k);
        tls::free(k);
        let a = tls::key_generate(tls::P256);
        challenge = tls::self_signed(a, ["acme.test"], 1);
        challenge_key = tls::key_pem(a);
        tls::free(a);
    };
    assert(failed.len == 0);
    let ctx, ok = tls::server(normal, normal_key, ["h2", "http/1.1"]);
    assert(ok);
    assert(tls::choose_context(ctx));
    let actx, aok = tls::server(challenge, challenge_key, ["acme-tls/1"]);
    assert(aok);
    let chooser = Chooser { challenge: actx };
    let ring = unix_address("rest-choose-ring.sock");
    let epoll = unix_address("rest-choose-epoll.sock");
    let w = [
        thread_spawn(ring_worker, http::Config { address: ring, workers: 1, tls: true, .. }, ctx, chooser),
        thread_spawn(epoll_worker, http::Config { address: epoll, workers: 1, tls: true, .. }, ctx, chooser),
    ];
    print("serve:");
    clients(ring, normal, challenge);
    print("serve_epoll:");
    clients(epoll, normal, challenge);
    http::stop();
    for t in w { thread_wait(t); }
    tls::free(actx);
    tls::free(ctx);
}
