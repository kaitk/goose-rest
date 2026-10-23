// plod::routes with plod::get and its kin: each method's route, HEAD on a
// GET, a failure in a route's block, a guard, scopes behind plod::bearer and
// behind a stack that opens plod::route, a scope's own plod::otherwise before
// and after a route that took the request, and
// what routes answers itself when no route did: 404, 405 with Allow,
// OPTIONS, 501, and 400 for a dot-segment. Each answer is printed whole but
// for its body, so a second answer appended would show.
import std;
import http from "github.com/kaitk/goose-http@v0.5.6";
import plod from "../../";
import expect from "../";

fn admin(cx) -> bool {
    let v, has = plod::header(cx, "X-Admin");
    return has && v == "yes";
}

fn project(cx, id: i64) {
    guard id != 0 else { plod::fail(cx, 404, "project_not_found"); }
    plod::text(cx, 200, str("project ", id));
}

// A stack of the program's own: its plod::route joins routes' route.
inline fn signed_in<F>(cx) {
    plod::route(cx) {
        plod::bearer(cx) { token =>
            guard token == "secret" else { plod::invalid_token(cx); }
            F();
        };
    };
}

fn handle(cx) {
    plod::routes(cx) { cx =>
        plod::get(cx, "/projects/:id") { project(cx, plod::param_int(cx, "id")); };
        plod::post(cx, "/projects") { plod::text(cx, 201, "created"); };
        plod::put(cx, "/projects/:id") { plod::text(cx, 200, "put"); };
        plod::patch(cx, "/projects/:id") { plod::text(cx, 200, "patched"); };
        plod::delete(cx, "/projects/:id") { plod::empty(cx, 204); };
        if admin(cx) { plod::get(cx, "/admin") { plod::text(cx, 200, "admin"); }; }
        plod::scope(cx, "/reports") {
            plod::bearer(cx) { token =>
                guard token == "secret" else { plod::invalid_token(cx); }
                plod::get(cx, "/daily") { plod::text(cx, 200, "daily"); };
            };
        };
        plod::scope(cx, "/team") {
            signed_in(cx) { plod::get(cx, "/members") { plod::text(cx, 200, "members"); }; };
        };
        plod::scope(cx, "/old") {
            if plod::on(cx, "GET", "/list") { plod::text(cx, 200, "list"); }
            else { plod::otherwise(cx); }
        };
        // plod::otherwise after a route that took the request answers nothing.
        plod::scope(cx, "/late") {
            plod::get(cx, "/list") { plod::text(cx, 200, "late list"); };
            plod::otherwise(cx);
        };
    };
}

fn ask(text: const u8[:]) {
    let out = plod::serve_one(text) { cx => handle(cx) };
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
