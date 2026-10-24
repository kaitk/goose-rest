// plod::serve and plod::serve_epoll with a TlsServer, each on a Unix socket in
// TMPDIR whose listener serves TLS, with a certificate goose-tls makes here: a
// route's answer, an error, and a WebSocket's echo over wss, each read by a
// client of goose-tls's that trusts the certificate.
import std;
import os;
import http from "github.com/kaitk/goose-http@999757063408a9a50c7a865dcad309a213489e33";
import tls from "github.com/kaitk/goose-tls@v0.0.5";
import hash from "github.com/kaitk/goose-hash@v0.0.4";
import plod from "../../";
import plod.tls;
import plod.websocket;

enum Use { None, Echo }

struct St { use: Use = Use.None, ws: http::WebSocket = http::WebSocket { .. } }

fn handle(cx) {
    if plod::resumed(cx) {
        plod::on_reply(cx) { resume(cx.state.use, cx); };
    } else {
        plod::routes(cx) { cx =>
            plod::get(cx, "/hello") { plod::text(cx, 200, "hello over TLS"); };
            plod::get(cx, "/ws") { plod::ws_upgrade(cx, cx.state.ws, Use.Echo); };
        };
    }
}

fn resume(u: Use.None, cx) { plod::fail(cx, 500, "not_waiting"); }

fn resume(u: Use.Echo, cx) {
    plod::ws_read(cx, cx.state.ws) { op, data => http::ws_send(cx.out, op, data); };
}

thread_fn ring_worker(cfg: http::Config, ctx: tls::Context) {
    var server = http::tls_server(ctx);
    var app = plod::NoState { .. };
    let e = plod::serve(cfg, app, St { .. }, server) { cx => handle(cx); };
    http::release(server);
    if e.code != 0 { http::report(e); }
}

thread_fn epoll_worker(cfg: http::Config, ctx: tls::Context) {
    var server = http::tls_server(ctx);
    var app = plod::NoState { .. };
    let e = plod::serve_epoll(cfg, app, St { .. }, server) { cx => handle(cx); };
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

// What the server at address sends back to text, over TLS, until it closes.
fn talk(address: const u8[:], ctx: tls::Context, text: const u8[:]) -> u8[>..] {
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
    let c = tls::connect(ctx, "localhost");
    var wire: u8[16384] = [0; 16384];
    loop {
        let r = tls::handshake(c);
        flush(s, c);
        if r == 0 { break; }
        assert(r == tls::WANT_INPUT);
        let n = http::recv(s, wire, 5000);
        assert(n > 0);
        tls::feed(c, wire[..n]);
    }
    assert(tls::write(c, text) == text.len);
    flush(s, c);
    var got: u8[>..] = [];
    var plain: u8[16384] = [0; 16384];
    loop {
        let n = tls::read(c, plain);
        if n > 0 {
            got.append(plain[..n]);
            continue;
        }
        if n == tls::CLOSED { break; }
        assert(n == tls::WANT_INPUT);
        let m = http::recv(s, wire, 5000);
        if m <= 0 { break; }
        tls::feed(c, wire[..m]);
    }
    tls::free(c);
    http::hangup(s);
    return got;
}

// A frame as a client sends it, masked.
fn frame(out: u8[>..]&, first: u8, data: const u8[:]) {
    let mask: u8[4] = [9, 8, 7, 6];
    out.push(first);
    out.push(0x80 | data.len as! u8);
    out.append(mask);
    for b, i in data { out.push(b ^ mask[i & 3]); }
}

// The answer without its Date and Server fields.
fn shown(got: const u8[:]) -> u8[>..] {
    var out: u8[>..] = [];
    var at = 0;
    while at < got.len {
        var end = find(got[at..], "\r\n");
        end = if end < 0 { got.len } else { at + end + 2 };
        let line = got[at..end];
        if !starts_with(line, "Date: ") && !starts_with(line, "Server: ") { out.append(line); }
        at = end;
    }
    return out;
}

fn requests(address: const u8[:], client: tls::Context) {
    print(shown(talk(address, client, "GET /hello HTTP/1.1\r\nHost: x\r\nConnection: close\r\n\r\n")));
    print(shown(talk(address, client, "GET /none HTTP/1.1\r\nHost: x\r\nConnection: close\r\n\r\n")));
    var frames: u8[>..] = [];
    frame(frames, 0x81, "over wss");
    frame(frames, 0x88, "\x03\xe8");
    let ws = talk(address, client, str("GET /ws HTTP/1.1\r\nHost: x\r\nConnection: Upgrade\r\nUpgrade: websocket\r\n",
                                       "Sec-WebSocket-Version: 13\r\nSec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n\r\n",
                                       frames));
    let head = find(ws, "\r\n\r\n") + 4;
    print(shown(ws[..head]));
    assert(ws[head..] == "\x81\x08over wss\x88\x02\x03\xe8");
    print("echoed over wss");
}

fn main() {
    var chain: u8[>..] = [];
    var key: u8[>..] = [];
    let failed = tls::run() {
        let k = tls::key_generate(tls::P256);
        chain = tls::self_signed(k, ["localhost"], 1);
        key = tls::key_pem(k);
        tls::free(k);
    };
    assert(failed.len == 0);
    let ctx, ok = tls::server(chain, key, ["http/1.1"]);
    assert(ok);
    let client, trusted = tls::client_trusting(chain, ["http/1.1"]);
    assert(trusted);
    let ring = unix_address("rest-tls-ring.sock");
    let epoll = unix_address("rest-tls-epoll.sock");
    let w = [
        thread_spawn(ring_worker, http::Config { address: ring, workers: 1, tls: true, .. }, ctx),
        thread_spawn(epoll_worker, http::Config { address: epoll, workers: 1, tls: true, .. }, ctx),
    ];
    print("== serve");
    requests(ring, client);
    print("== serve_epoll");
    requests(epoll, client);
    http::stop();
    for t in w { thread_wait(t); }
    tls::free(client);
    tls::free(ctx);
}
