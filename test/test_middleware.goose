// The middleware and scopes, byte for byte: CORS for a simple request, a
// refused origin, a preflight, and an error inside; the bearer check; the
// Server-Timing field; prefix scopes with 404, 405, and OPTIONS across
// them; and both middlewares' fields on answers at a later call, at WAKE,
// TIMEOUT, and a body's END. scripts/test-unit.sh runs this through TinyCC.
import std;
import http from "github.com/kaitk/goose-http@v0.3.2";
import rest from "../";

fn same(got: const u8[:], want: const u8[:]) {
    if got != want {
        print("got:\n", got, "\nwant:\n", want);
        assert(false);
    }
}

// Calls H with a context for text, a whole request, and returns what it
// wrote.
fn answer<H>(text: const u8[:]) -> u8[>..] {
    let req, status = http::parse(text);
    if status != 200 { print("parse: ", status, "\n", text); assert(false); }
    var out: u8[>..] = [];
    var keep = true;
    var st = http::Stream { .. };
    var state = rest::NoState { .. };
    var scratch: u8[>..] = [];
    var app = rest::NoState { .. };
    var none = rest::NoRouter { .. };
    var cx = rest::Cx<rest::NoState, rest::NoState, rest::NoRouter> { req: req, body: text[req.len..],
                                       out: http::Reply { buf: out, common: "", keep_alive: keep, minor: 1,
                                       head: req.method == "HEAD", stream: st }, state: state, app: app,
                                       scratch: scratch, router: none };
    H(cx);
    return out;
}

fn request(method: const u8[:], target: const u8[:], fields: const u8[:] = "") -> u8[>..] {
    str(method, " ", target, " HTTP/1.1\r\nHost: x\r\n", fields, "\r\n")
}

let OK = "Content-Type: text/plain; charset=utf-8\r\nContent-Length: 2\r\n\r\nok";

// A handler behind CORS: /missing fails 404 inside it.
fn with_cors(text: const u8[:]) -> u8[>..] {
    return answer(text) { cx =>
        rest::cors(cx, rest::Cors { origins: "https://a.example https://b.example", expose: "X-Total", .. }) {
            rest::route(cx) {
                guard http::path_of(cx.req.target) != "/missing" else { rest::fail(cx, 404, "not_found"); }
                rest::text(cx, 200, "ok");
            };
        };
    };
}

fn test_cors() {
    same(with_cors(request("GET", "/")), str("HTTP/1.1 200 OK\r\n", OK));
    same(with_cors(request("GET", "/", "Origin: https://b.example\r\n")),
         str("HTTP/1.1 200 OK\r\nAccess-Control-Allow-Origin: https://b.example\r\n",
             "Access-Control-Expose-Headers: X-Total\r\nVary: Origin\r\n", OK));
    same(with_cors(request("GET", "/missing", "Origin: https://a.example\r\n")),
         str("HTTP/1.1 404 Not Found\r\nAccess-Control-Allow-Origin: https://a.example\r\n",
             "Access-Control-Expose-Headers: X-Total\r\nVary: Origin\r\n",
             "Content-Type: application/json\r\nContent-Length: 21\r\n\r\n{\"error\":\"not_found\"}"));
    same(with_cors(request("GET", "/", "Origin: https://a.example.evil\r\n")),
         str("HTTP/1.1 403 Forbidden\r\nContent-Type: application/json\r\nContent-Length: 30\r\n\r\n",
             "{\"error\":\"origin_not_allowed\"}"));
    same(with_cors(request("OPTIONS", "/", "Origin: https://a.example\r\nAccess-Control-Request-Method: PUT\r\n")),
         str("HTTP/1.1 204 No Content\r\nAccess-Control-Allow-Origin: https://a.example\r\n",
             "Access-Control-Allow-Methods: GET, HEAD, POST, PUT, PATCH, DELETE\r\n",
             "Access-Control-Allow-Headers: Authorization, Content-Type\r\nAccess-Control-Max-Age: 600\r\n",
             "Vary: Origin, Access-Control-Request-Method, Access-Control-Request-Headers\r\n\r\n"));
    // OPTIONS without Access-Control-Request-Method isn't a preflight.
    same(with_cors(request("OPTIONS", "/", "Origin: https://a.example\r\n")),
         str("HTTP/1.1 200 OK\r\nAccess-Control-Allow-Origin: https://a.example\r\n",
             "Access-Control-Expose-Headers: X-Total\r\nVary: Origin\r\n", OK));
    let any = answer(request("GET", "/", "Origin: https://c.example\r\n")) { cx =>
        rest::cors(cx, rest::Cors { origins: "*", credentials: true, .. }) { rest::text(cx, 200, "ok"); };
    };
    same(any, str("HTTP/1.1 200 OK\r\nAccess-Control-Allow-Origin: https://c.example\r\n",
                  "Access-Control-Allow-Credentials: true\r\nVary: Origin\r\n", OK));
}

fn with_bearer(fields: const u8[:]) -> u8[>..] {
    return answer(request("GET", "/", fields)) { cx =>
        rest::route(cx) {
            rest::bearer(cx) { token =>
                guard token == "t0k" else { rest::invalid_token(cx); }
                rest::text(cx, 200, "ok");
            };
        };
    };
}

fn test_bearer() {
    same(with_bearer("Authorization: Bearer t0k\r\n"), str("HTTP/1.1 200 OK\r\n", OK));
    same(with_bearer("Authorization: bearer   t0k\r\n"), str("HTTP/1.1 200 OK\r\n", OK));
    let none = "HTTP/1.1 401 Unauthorized\r\nWWW-Authenticate: Bearer\r\nContent-Type: application/json\r\nContent-Length: 27\r\n\r\n{\"error\":\"unauthenticated\"}";
    same(with_bearer(""), none);
    same(with_bearer("Authorization: Basic YTpi\r\n"), none);
    same(with_bearer("Authorization: Bearer\r\n"), none);
    same(with_bearer("Authorization: Bearer nope\r\n"),
         str("HTTP/1.1 401 Unauthorized\r\nWWW-Authenticate: Bearer error=\"invalid_token\"\r\n",
             "Content-Type: application/json\r\nContent-Length: 25\r\n\r\n{\"error\":\"invalid_token\"}"));
}

fn test_timed() {
    let out = answer(request("GET", "/")) { cx => rest::timed(cx, false) { rest::text(cx, 200, "ok"); }; };
    let head = "HTTP/1.1 200 OK\r\nServer-Timing: app;dur=";
    same(out[..head.len], head);
    let rest_at = find(out, "\r\nContent-Type");
    // The value, padded with spaces to a fixed width.
    assert(rest_at - head.len == 12);
    let padded = out[head.len..rest_at];
    let dur = padded[..find(padded, " ")];
    for c in padded[dur.len..] { assert(c == ' '); }
    let dot = find(dur, ".");
    assert(dot >= 1 && dur.len == dot + 4);
    for c, i in dur { assert(i == dot || c >= '0' && c <= '9'); }
    same(out[rest_at + 2..], OK);
    // Nothing written, nothing added.
    same(answer(request("GET", "/")) { cx => rest::timed(cx, false) {}; }, "");
}

// Scopes over an if chain: /v1 holds /projects, its root, and /admin, which
// holds /users; /health is outside.
fn scoped(text: const u8[:]) -> u8[>..] {
    return answer(text) { cx =>
        rest::routes(cx) { cx =>
            if rest::scope(cx, "/v1") {
                if rest::on(cx, "GET", "") { rest::text(cx, 200, "v1"); }
                else if rest::on(cx, "GET", "/projects") { rest::text(cx, 200, "list"); }
                else if rest::on(cx, "POST", "/projects") { rest::text(cx, 200, "create"); }
                else if rest::scope(cx, "/admin") {
                    if rest::on(cx, "DELETE", "/users/:id") {
                        rest::route(cx) { rest::text(cx, 200, str("delete ", rest::param(cx, "id"))); };
                    }
                    else { rest::otherwise(cx); }
                }
                else { rest::otherwise(cx); }
            } else if rest::on(cx, "GET", "/health") {
                rest::text(cx, 200, "health");
            } else {
                rest::otherwise(cx);
            }
        };
    };
}

fn body_of(out: const u8[:]) -> const u8[:] { out[find(out, "\r\n\r\n") + 4..] }

fn status_of(out: const u8[:]) -> const u8[:] { out[..find(out, "\r\n")] }

fn test_scopes() {
    same(body_of(scoped(request("GET", "/v1/projects"))), "list");
    same(body_of(scoped(request("POST", "/v1/projects"))), "create");
    same(body_of(scoped(request("GET", "/v1"))), "v1");
    same(body_of(scoped(request("GET", "/%761/projects"))), "list");
    same(body_of(scoped(request("DELETE", "/v1/admin/users/7"))), "delete 7");
    same(body_of(scoped(request("GET", "/health"))), "health");
    same(scoped(request("DELETE", "/v1/projects")),
         str("HTTP/1.1 405 Method Not Allowed\r\nAllow: GET, HEAD, POST\r\nContent-Type: application/json\r\n",
             "Content-Length: 30\r\n\r\n{\"error\":\"method_not_allowed\"}"));
    same(scoped(request("OPTIONS", "/v1/projects")), "HTTP/1.1 204 No Content\r\nAllow: GET, HEAD, POST\r\n\r\n");
    same(scoped(request("GET", "/v1/admin/users/7")),
         str("HTTP/1.1 405 Method Not Allowed\r\nAllow: DELETE\r\nContent-Type: application/json\r\n",
             "Content-Length: 30\r\n\r\n{\"error\":\"method_not_allowed\"}"));
    let missing = str("HTTP/1.1 404 Not Found\r\nContent-Type: application/json\r\nContent-Length: 21\r\n\r\n",
                      "{\"error\":\"not_found\"}");
    same(scoped(request("GET", "/v1/nope")), missing);
    same(scoped(request("GET", "/v1/")), missing);
    same(scoped(request("GET", "/v10/projects")), missing);
    same(scoped(request("GET", "/v1/admin")), missing);
    same(status_of(scoped(request("GET", "/v1/../health"))), "HTTP/1.1 400 Bad Request");
    same(status_of(scoped(request("BREW", "/v1/projects"))), "HTTP/1.1 501 Not Implemented");
}

// Answers at a later call, behind CORS and Server-Timing: a route that asks
// and answers the reply at WAKE, or 504 at TIMEOUT, and one that reads its
// body in pieces and answers at the END.
enum Waiting { None, Report, Upload }

struct St { waiting: Waiting = Waiting.None, size: i64 = 0 }

let CORS = rest::Cors { origins: "https://a.example", expose: "X-Total", .. };

let ALLOWED = "Access-Control-Allow-Origin: https://a.example\r\nAccess-Control-Expose-Headers: X-Total\r\nVary: Origin\r\n";

fn resume(w: Waiting.None, cx) { rest::fail(cx, 500, "not_waiting"); }

fn resume(w: Waiting.Report, cx) { rest::text(cx, 200, str("got ", cx.reply)); }

fn resume(w: Waiting.Upload, cx) {
    if cx.kind == http::BODY { cx.state.size += cx.body.len; }
    else if cx.kind == http::END { rest::text(cx, 201, str(cx.state.size)); }
}

// The route of what, behind the middleware of which: "cors", "timed", or
// both, timed outside. "ask" asks to, "upload" reads its body in pieces, and
// "gathered" asks once rest::body has the body whole.
fn later_route(cx, what: const u8[:], which: const u8[:], to: http::MailAddress) {
    fn inner() {
        rest::route(cx) {
            if what == "upload" {
                rest::body_in_pieces(cx, 1 << 20, Waiting.Upload);
            } else {
                if what == "gathered" { rest::body(cx); }
                rest::ask(cx, to, 1, 7, Waiting.Report);
            }
        };
    }
    if which == "cors" {
        rest::cors(cx, CORS) { inner(); };
    } else if which == "timed" {
        rest::timed(cx, false) { inner(); };
    } else {
        rest::timed(cx, false) { rest::cors(cx, CORS) { inner(); }; };
    }
}

// What serve answers to text, whose route asks, given the reply, or TIMEOUT
// for none: the REQUEST, the body's pieces when it doesn't come whole, and
// then the WAKE. common is the loop's fields, another at the WAKE, as Date's
// value changes. The exchange keeps nothing after.
fn answered_later(text: const u8[:], which: const u8[:], reply: const u8[:], timeout: bool = false,
                  what: const u8[:] = "ask") -> u8[>..] {
    let box, e = http::mail_open(2, 256);
    http::exit_on_error(e);
    let to = http::address(box, 0);
    let req, status = http::parse(text);
    if status != 200 { print("parse: ", status, "\n", text); assert(false); }
    let body = text[req.len..];
    let whole = what != "gathered";
    var out: u8[>..] = [];
    var keep = true;
    var stream = http::Stream { .. };
    var st = rest::Slot<St> { state: St { .. } };
    reusable[] var spill: u8[>..] = [];
    var runs: rest::Run[>..] = [];
    var budget = rest::Budget { size: rest::GATHER_BUDGET, runs: runs };
    var app = rest::NoState { .. };
    let first = http::Reply { buf: out, common: "Server: t\r\n", keep_alive: keep, minor: 1, head: false,
                              stream: stream };
    fn send(kind: u8, data: const u8[:]) {
        rest::deliver(http::Event { kind: kind, req: req, data: data, whole: whole, trailers: "" }, st, app, first, spill, budget)
            { cx => later_route(cx, what, which, to); };
    }
    send(http::REQUEST, if whole { body } else { "" });
    if !whole {
        send(http::BODY, body);
        send(http::END, "");
    }
    if !stream.waiting || out.len > 0 { print(which, " ", what, ": ", out); assert(false); }
    let n = http::mail_take(box) { key, tag, bytes => assert(tag == 1); };
    assert(n == 1);
    sleep_ms(2);
    stream.waiting = false;
    let none = http::Request { .. };
    let later = http::Reply { buf: out, common: "Server: t2\r\n", keep_alive: keep, minor: 1, head: false,
                              stream: stream };
    rest::deliver(http::Event { kind: if timeout { http::TIMEOUT } else { http::WAKE }, req: none, data: reply,
                                whole: false, trailers: "" }, st, app, later, spill, budget) { cx =>
        if rest::resumed(cx) { resume(cx.state.waiting, cx); } else { later_route(cx, what, which, to); }
    };
    assert(st.ex.mode == 0 && st.ex.cap == 0);
    return out;
}

// Checks out's Server-Timing, after its status line and the loop's fields:
// a value of at least least milliseconds, padded. Returns what follows it.
fn timing_in(out: const u8[:], least: i64) -> const u8[:] {
    let head = find(out, "\r\nServer-Timing: app;dur=") + 25;
    assert(head >= 25);
    let end = find(out[head..], "\r\n");
    assert(end == 12);
    let dur = out[head..head + find(out[head..], " ")];
    let ms, ok = parse_int(dur[..find(dur, ".")]);
    assert(ok && ms >= least);
    return out[head + end + 2..];
}

fn test_later() {
    let get = request("GET", "/report", "Origin: https://a.example\r\n");
    let got = "Content-Type: text/plain; charset=utf-8\r\nContent-Length: 6\r\n\r\ngot ok";
    same(answered_later(get, "cors", "ok"), str("HTTP/1.1 200 OK\r\nServer: t2\r\n", ALLOWED, got));
    // Without Origin, nothing kept.
    let plain = request("GET", "/report");
    same(answered_later(plain, "cors", "ok"), str("HTTP/1.1 200 OK\r\nServer: t2\r\n", got));
    // Timed from the request, which came 2 ms before the reply.
    let timed = answered_later(plain, "timed", "ok");
    same(status_of(timed), "HTTP/1.1 200 OK");
    same(timing_in(timed, 2), got);
    let both = answered_later(get, "both", "ok");
    same(timing_in(both, 2), str(ALLOWED, got));
    // TIMEOUT's 504.
    let late = answered_later(get, "both", "", true);
    same(status_of(late), "HTTP/1.1 504 Gateway Timeout");
    same(timing_in(late, 2),
         str(ALLOWED, "Content-Type: application/json\r\nContent-Length: 19\r\n\r\n{\"error\":\"timeout\"}"));
    // A body gathered first, and then the ask.
    let posted = str("POST /report HTTP/1.1\r\nHost: x\r\nOrigin: https://a.example\r\nContent-Length: 5\r\n\r\nhello");
    same(answered_later(posted, "cors", "ok", false, "gathered"),
         str("HTTP/1.1 200 OK\r\nServer: t2\r\n", ALLOWED, got));
}

// Answers a body read in pieces at its END, through serve_one.
fn upload(which: const u8[:], n: i64) -> u8[>..] {
    var text = str("POST /up HTTP/1.1\r\nHost: x\r\nOrigin: https://a.example\r\nContent-Length: ", n, "\r\n\r\n");
    for i in n { text.push('a'); }
    var app = rest::NoState { .. };
    let to = http::MailAddress { .. };
    return rest::serve_one(text, app, St { .. }) { cx =>
        if rest::resumed(cx) { resume(cx.state.waiting, cx); } else { later_route(cx, "upload", which, to); }
    };
}

fn test_end() {
    // Whole with its head, and in pieces.
    for n in [100, 20000] {
        let size = str(n);
        let created = str("Content-Type: text/plain; charset=utf-8\r\nContent-Length: ", size.len, "\r\n\r\n", size);
        same(upload("cors", n), str("HTTP/1.1 201 Created\r\n", ALLOWED, created));
        let both = upload("both", n);
        same(status_of(both), "HTTP/1.1 201 Created");
        same(timing_in(both, 0), str(ALLOWED, created));
    }
}

fn main() {
    test_cors();
    test_bearer();
    test_timed();
    test_scopes();
    test_later();
    test_end();
    print("test_middleware: ok");
}
