// rest::routes with rest::get and its kin: each method's route, HEAD on a
// GET, a failure in a route's block, a guard, scopes behind rest::bearer and
// behind a stack that opens rest::route, a scope's own rest::otherwise before
// and after a route that took the request, and
// what routes answers itself when no route did: 404, 405 with Allow,
// OPTIONS, 501, and 400 for a dot-segment. Each answer is printed whole but
// for its body, so a second answer appended would show.
import std;
import http from "github.com/kaitk/goose-http@v0.5.0";
import rest from "../../";
import expect from "../";

fn admin(cx) -> bool {
    let v, has = rest::header(cx, "X-Admin");
    return has && v == "yes";
}

fn project(cx, id: i64) {
    guard id != 0 else { rest::fail(cx, 404, "project_not_found"); }
    rest::text(cx, 200, str("project ", id));
}

// A stack of the program's own: its rest::route joins routes' route.
inline fn signed_in<F>(cx) {
    rest::route(cx) {
        rest::bearer(cx) { token =>
            guard token == "secret" else { rest::invalid_token(cx); }
            F();
        };
    };
}

fn handle(cx) {
    rest::routes(cx) { cx =>
        rest::get(cx, "/projects/:id") { project(cx, rest::param_int(cx, "id")); };
        rest::post(cx, "/projects") { rest::text(cx, 201, "created"); };
        rest::put(cx, "/projects/:id") { rest::text(cx, 200, "put"); };
        rest::patch(cx, "/projects/:id") { rest::text(cx, 200, "patched"); };
        rest::delete(cx, "/projects/:id") { rest::empty(cx, 204); };
        if admin(cx) { rest::get(cx, "/admin") { rest::text(cx, 200, "admin"); }; }
        rest::scope(cx, "/reports") {
            rest::bearer(cx) { token =>
                guard token == "secret" else { rest::invalid_token(cx); }
                rest::get(cx, "/daily") { rest::text(cx, 200, "daily"); };
            };
        };
        rest::scope(cx, "/team") {
            signed_in(cx) { rest::get(cx, "/members") { rest::text(cx, 200, "members"); }; };
        };
        rest::scope(cx, "/old") {
            if rest::on(cx, "GET", "/list") { rest::text(cx, 200, "list"); }
            else { rest::otherwise(cx); }
        };
        // rest::otherwise after a route that took the request answers nothing.
        rest::scope(cx, "/late") {
            rest::get(cx, "/list") { rest::text(cx, 200, "late list"); };
            rest::otherwise(cx);
        };
    };
}

fn ask(text: const u8[:]) {
    let out = rest::serve_one(text) { cx => handle(cx) };
    print(str(text[..text.find(" HTTP/")], ":"));
    var at = 0;
    while at < out.len {
        var end = out[at..].find("\r\n");
        if end < 0 { end = out.len - at; }
        if out[at..at + end].len > 0 { print(str("  ", out[at..at + end])); }
        at += end + 2;
    }
}

fn main() {
    ask("GET /projects/7 HTTP/1.1\r\n\r\n");
    ask("HEAD /projects/7 HTTP/1.1\r\n\r\n");
    ask("GET /projects/0 HTTP/1.1\r\n\r\n");
    ask("GET /projects/x HTTP/1.1\r\n\r\n");
    ask("POST /projects HTTP/1.1\r\nContent-Length: 0\r\n\r\n");
    ask("PUT /projects/7 HTTP/1.1\r\nContent-Length: 0\r\n\r\n");
    ask("PATCH /projects/7 HTTP/1.1\r\nContent-Length: 0\r\n\r\n");
    ask("DELETE /projects/7 HTTP/1.1\r\n\r\n");
    ask("POST /projects/7 HTTP/1.1\r\nContent-Length: 0\r\n\r\n");
    ask("OPTIONS /projects/7 HTTP/1.1\r\n\r\n");
    ask("OPTIONS * HTTP/1.1\r\n\r\n");
    ask("GET /nothing HTTP/1.1\r\n\r\n");
    ask("BREW /projects/7 HTTP/1.1\r\n\r\n");
    ask("GET /a/../projects/7 HTTP/1.1\r\n\r\n");
    ask("GET /admin HTTP/1.1\r\nX-Admin: yes\r\n\r\n");
    ask("GET /admin HTTP/1.1\r\n\r\n");
    ask("GET /reports/daily HTTP/1.1\r\nAuthorization: Bearer secret\r\n\r\n");
    ask("GET /reports/daily HTTP/1.1\r\n\r\n");
    ask("GET /reports/weekly HTTP/1.1\r\nAuthorization: Bearer secret\r\n\r\n");
    ask("POST /reports/daily HTTP/1.1\r\nAuthorization: Bearer secret\r\nContent-Length: 0\r\n\r\n");
    ask("GET /team/members HTTP/1.1\r\nAuthorization: Bearer secret\r\n\r\n");
    ask("GET /team/members HTTP/1.1\r\nAuthorization: Bearer wrong\r\n\r\n");
    ask("GET /team/nope HTTP/1.1\r\nAuthorization: Bearer secret\r\n\r\n");
    ask("GET /old/list HTTP/1.1\r\n\r\n");
    ask("DELETE /old/list HTTP/1.1\r\n\r\n");
    ask("GET /late/list HTTP/1.1\r\n\r\n");
    ask("DELETE /late/list HTTP/1.1\r\n\r\n");
}
