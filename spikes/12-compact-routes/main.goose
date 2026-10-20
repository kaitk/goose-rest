// Spike 12: the same routes in today's form and the shorter one, each
// request answered by both, which must answer alike: routes that match, a
// failure, 404, 405 with Allow, OPTIONS, 501, a guard, scopes in today's
// form inside the shorter one, behind middleware or with their own
// rest::otherwise, and a route that gathers its body. ask compares whole
// answers, so a second answer appended would show. README.md has the
// verdict.
import std;
import http from "github.com/kaitk/goose-http@v0.4.3";
import rest from "../../";
import .compact;

struct St { admin: bool = false }

fn admin(cx) -> bool {
    let v, has = rest::header(cx, "X-Admin");
    return has && v == "yes";
}

fn project(cx, id: i64) {
    guard id != 0 else { rest::fail(cx, 404, "project_not_found"); }
    rest::text(cx, 200, str("project ", id));
}

fn reports(cx) {
    rest::bearer(cx) { token =>
        guard token == "secret" else { rest::invalid_token(cx); }
        if rest::on(cx, "GET", "/daily") { rest::text(cx, 200, "daily"); }
    };
}

// Today's form, rest::otherwise included, as a program has it before it moves.
fn old(cx) {
    if rest::on(cx, "GET", "/list") { rest::text(cx, 200, "list"); }
    else { rest::otherwise(cx); }
}

fn long(cx) {
    rest::routes(cx) { cx =>
        if rest::on(cx, "GET", "/health") {
            rest::route(cx) { rest::text(cx, 200, "ok"); };
        } else if rest::on(cx, "GET", "/projects/:id") {
            rest::route(cx) { project(cx, rest::param_int(cx, "id")); };
        } else if rest::on(cx, "DELETE", "/projects/:id") {
            rest::route(cx) { rest::empty(cx, 204); };
        } else if rest::on(cx, "GET", "/admin") && admin(cx) {
            rest::route(cx) { rest::text(cx, 200, "admin"); };
        } else if rest::on(cx, "PUT", "/upload") {
            rest::route(cx) { rest::text(cx, 200, str(rest::body(cx).len)); };
        } else if rest::scope(cx, "/reports") {
            rest::route(cx) {
                rest::bearer(cx) { token =>
                    guard token == "secret" else { rest::invalid_token(cx); }
                    if rest::on(cx, "GET", "/daily") { rest::text(cx, 200, "daily"); }
                    else { rest::otherwise(cx); }
                };
            };
        } else if rest::scope(cx, "/old") {
            rest::route(cx) { old(cx); };
        } else {
            rest::otherwise(cx);
        }
    };
}

fn short(cx) {
    compact::routes(cx) { cx =>
        compact::get(cx, "/health") { rest::text(cx, 200, "ok"); };
        compact::get(cx, "/projects/:id") { project(cx, rest::param_int(cx, "id")); };
        compact::delete(cx, "/projects/:id") { rest::empty(cx, 204); };
        // A guard: the route matches only for an admin, as rest::on's && does.
        if admin(cx) { compact::get(cx, "/admin") { rest::text(cx, 200, "admin"); }; }
        compact::put(cx, "/upload") { rest::text(cx, 200, str(rest::body(cx).len)); };
        // A scope behind middleware, in today's form: one route around it.
        if rest::scope(cx, "/reports") { rest::route(cx) { reports(cx); }; }
        else if rest::scope(cx, "/old") { rest::route(cx) { old(cx); }; }
    };
}

fn ask(text: const u8[:]) {
    var app = rest::NoState { .. };
    let a = rest::serve_one(text, app, St { .. }) { cx => long(cx) };
    let b = rest::serve_one(text, app, St { .. }) { cx => short(cx) };
    let head = text[..text.find("\r\n")];
    if a == b {
        print(str(head, " -> ", a[..a.find("\r\n")]));
        let allow = a.find("Allow: ");
        if allow >= 0 { print(str("  ", a[allow..allow + a[allow..].find("\r\n")])); }
    } else {
        print(str(head, " -> today ", a[..a.find("\r\n")], ", shorter ", b[..b.find("\r\n")]));
    }
}

fn put(n: i64) -> u8[>..] {
    var text = str("PUT /upload HTTP/1.1\r\nHost: x\r\nContent-Length: ", n, "\r\n\r\n");
    for i in n { text.push('a'); }
    return text;
}

fn main() {
    ask("GET /health HTTP/1.1\r\nHost: x\r\n\r\n");
    ask("HEAD /health HTTP/1.1\r\nHost: x\r\n\r\n");
    ask("GET /projects/7 HTTP/1.1\r\nHost: x\r\n\r\n");
    ask("GET /projects/0 HTTP/1.1\r\nHost: x\r\n\r\n");
    ask("GET /projects/x HTTP/1.1\r\nHost: x\r\n\r\n");
    ask("DELETE /projects/7 HTTP/1.1\r\nHost: x\r\n\r\n");
    ask("POST /projects/7 HTTP/1.1\r\nHost: x\r\nContent-Length: 0\r\n\r\n");
    ask("OPTIONS /projects/7 HTTP/1.1\r\nHost: x\r\n\r\n");
    ask("OPTIONS * HTTP/1.1\r\nHost: x\r\n\r\n");
    ask("GET /nothing HTTP/1.1\r\nHost: x\r\n\r\n");
    ask("BREW /health HTTP/1.1\r\nHost: x\r\n\r\n");
    ask("GET /a/../health HTTP/1.1\r\nHost: x\r\n\r\n");
    ask("GET /admin HTTP/1.1\r\nHost: x\r\nX-Admin: yes\r\n\r\n");
    ask("GET /admin HTTP/1.1\r\nHost: x\r\n\r\n");
    ask("POST /admin HTTP/1.1\r\nHost: x\r\nX-Admin: yes\r\nContent-Length: 0\r\n\r\n");
    ask("POST /admin HTTP/1.1\r\nHost: x\r\nContent-Length: 0\r\n\r\n");
    ask(put(10));
    ask(put(100000));
    ask("GET /reports/daily HTTP/1.1\r\nHost: x\r\nAuthorization: Bearer secret\r\n\r\n");
    ask("GET /reports/daily HTTP/1.1\r\nHost: x\r\n\r\n");
    ask("GET /reports/weekly HTTP/1.1\r\nHost: x\r\nAuthorization: Bearer secret\r\n\r\n");
    ask("POST /reports/daily HTTP/1.1\r\nHost: x\r\nAuthorization: Bearer secret\r\nContent-Length: 0\r\n\r\n");
    ask("GET /old/list HTTP/1.1\r\nHost: x\r\n\r\n");
    ask("GET /old/nope HTTP/1.1\r\nHost: x\r\n\r\n");
    ask("DELETE /old/list HTTP/1.1\r\nHost: x\r\n\r\n");
}
