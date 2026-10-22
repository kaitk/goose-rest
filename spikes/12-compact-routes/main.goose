// Spike 12: the same routes in today's form and the shorter one, designs A
// and B, each request answered by all three, which must answer alike:
// routes that match, a failure, 404, 405 with Allow, OPTIONS, 501, a guard,
// a body that's gathered, an answer a lane gives later, and the short form
// inside scopes behind rest::bearer and behind a stack of the program's
// own, beside a scope still in today's form. ask compares whole answers, so
// a second answer appended would show. README.md has the verdict.
import std;
import http from "github.com/kaitk/goose-http@e128cb39d82c0fa45280452b1c434a55384e14d7";
import rest from "../../";
import .compact;
import .marked;

enum Jobs { Slow { n: i64 } }

enum Use { None, Slow }

struct St { use: Use = Use.None }

struct App { to: rest::Lane<Jobs, Use> }

fn admin(cx) -> bool {
    let v, has = rest::header(cx, "X-Admin");
    return has && v == "yes";
}

fn project(cx, id: i64) {
    guard id != 0 else { rest::fail(cx, 404, "project_not_found"); }
    rest::text(cx, 200, str("project ", id));
}

fn resume(u: Use.None, cx) { rest::fail(cx, 500, "not_waiting"); }
fn resume(u: Use.Slow, cx) { resume(rest::job<Jobs>(cx), cx); }
fn resume(u: Jobs.Slow, cx) { rest::text(cx, 200, str("slow ", rest::answer<i64>(cx))); }

fn run(u: Jobs.Slow, a) { rest::reply_value(a, u.n * 7); }

// A stack of the program's own, as today's open their route: in today's
// form with rest::route, and in the shorter one with compact::route, which
// inside routes joins its route.
inline fn signed_in_today<F>(cx) {
    rest::route(cx) {
        rest::bearer(cx) { token =>
            guard token == "secret" else { rest::invalid_token(cx); }
            F();
        };
    };
}

inline fn signed_in<F>(cx) {
    compact::route(cx) {
        rest::bearer(cx) { token =>
            guard token == "secret" else { rest::invalid_token(cx); }
            F();
        };
    };
}

// The stack in design B: its block takes the route's context, so that the
// routes inside match only.
inline fn signed_in_b<F>(cx) {
    marked::route(cx) { cx =>
        rest::bearer(cx) { token =>
            guard token == "secret" else { rest::invalid_token(cx); }
            F(cx);
        };
    };
}

// Today's form, rest::otherwise included, as a program has it before it moves.
fn old(cx) {
    if rest::on(cx, "GET", "/list") { rest::text(cx, 200, "list"); }
    else if rest::on(cx, "GET", "/slow") { rest::ask(cx, cx.app.to, Jobs.Slow { n: 3 }); }
    else { rest::otherwise(cx); }
}

fn long(cx) {
    if rest::resumed(cx) {
        rest::on_reply(cx) { resume(cx.state.use, cx); };
        return;
    }
    rest::routes(cx) { cx =>
        if rest::on(cx, "GET", "/health") {
            rest::route(cx) { rest::text(cx, 200, "ok"); };
        } else if rest::on(cx, "GET", "/projects/:id") {
            rest::route(cx) { project(cx, rest::param_int(cx, "id")); };
        } else if rest::on(cx, "DELETE", "/projects/:id") {
            rest::route(cx) { rest::empty(cx, 204); };
        } else if admin(cx) && rest::on(cx, "GET", "/admin") {
            rest::route(cx) { rest::text(cx, 200, "admin"); };
        } else if rest::on(cx, "PUT", "/upload") {
            rest::route(cx) { rest::text(cx, 200, str(rest::body(cx).len)); };
        } else if rest::on(cx, "GET", "/slow") {
            rest::route(cx) { rest::ask(cx, cx.app.to, Jobs.Slow { n: 6 }); };
        } else if compact::scope(cx, "/reports") {
            rest::route(cx) {
                rest::bearer(cx) { token =>
                    guard token == "secret" else { rest::invalid_token(cx); }
                    if rest::on(cx, "GET", "/daily") { rest::text(cx, 200, "daily"); }
                    else { rest::otherwise(cx); }
                };
            };
        } else if compact::scope(cx, "/team") {
            signed_in_today(cx) {
                if rest::on(cx, "GET", "/members") { rest::text(cx, 200, "members"); }
                else { rest::otherwise(cx); }
            };
        } else if compact::scope(cx, "/old") {
            rest::route(cx) { old(cx); };
        } else {
            rest::otherwise(cx);
        }
    };
}

fn short(cx) {
    if rest::resumed(cx) {
        rest::on_reply(cx) { resume(cx.state.use, cx); };
        return;
    }
    compact::routes(cx) { cx =>
        compact::get(cx, "/health") { rest::text(cx, 200, "ok"); };
        compact::get(cx, "/projects/:id") { project(cx, rest::param_int(cx, "id")); };
        compact::delete(cx, "/projects/:id") { rest::empty(cx, 204); };
        // A guard: the route matches only for an admin.
        if admin(cx) { compact::get(cx, "/admin") { rest::text(cx, 200, "admin"); }; }
        compact::put(cx, "/upload") { rest::text(cx, 200, str(rest::body(cx).len)); };
        compact::get(cx, "/slow") { rest::ask(cx, cx.app.to, Jobs.Slow { n: 6 }); };
        if compact::scope(cx, "/reports") {
            // Middleware that fails, inside routes' one route.
            rest::bearer(cx) { token =>
                guard token == "secret" else { rest::invalid_token(cx); }
                compact::get(cx, "/daily") { rest::text(cx, 200, "daily"); };
            };
        } else if compact::scope(cx, "/team") {
            signed_in(cx) { compact::get(cx, "/members") { rest::text(cx, 200, "members"); }; };
        } else if compact::scope(cx, "/old") {
            compact::route(cx) { old(cx); };
        }
    };
}

fn short_b(cx) {
    if rest::resumed(cx) {
        rest::on_reply(cx) { resume(cx.state.use, cx); };
        return;
    }
    marked::routes(cx) { cx =>
        marked::get(cx, "/health") { rest::text(cx, 200, "ok"); };
        marked::get(cx, "/projects/:id") { project(cx, rest::param_int(cx, "id")); };
        marked::delete(cx, "/projects/:id") { rest::empty(cx, 204); };
        if admin(cx) { marked::get(cx, "/admin") { rest::text(cx, 200, "admin"); }; }
        marked::put(cx, "/upload") { rest::text(cx, 200, str(rest::body(cx).len)); };
        marked::get(cx, "/slow") { rest::ask(cx, cx.app.to, Jobs.Slow { n: 6 }); };
        if compact::scope(cx, "/reports") {
            marked::route(cx) { cx =>
                rest::bearer(cx) { token =>
                    guard token == "secret" else { rest::invalid_token(cx); }
                    marked::get(cx, "/daily") { rest::text(cx, 200, "daily"); };
                };
            };
        } else if compact::scope(cx, "/team") {
            signed_in_b(cx) { cx => marked::get(cx, "/members") { rest::text(cx, 200, "members"); }; };
        } else if compact::scope(cx, "/old") {
            // Today's code, which reads routes' router, inside a route.
            marked::route(cx) { c => old(cx); };
        }
    };
}

fn ask(text: const u8[:], wakes: const rest::Wake[:] = []) {
    let box, e = http::mail_open(32, 256);
    http::exit_on_error(e);
    var app = App { to: rest::lane_of<Jobs>(box, Use.Slow) };
    let a = rest::serve_one(text, app, St { .. }, wakes) { cx => long(cx) };
    let b = rest::serve_one(text, app, St { .. }, wakes) { cx => short(cx) };
    let c = rest::serve_one(text, app, St { .. }, wakes) { cx => short_b(cx) };
    let head = text[..text.find("\r\n")];
    if a == b && a == c {
        print(str(head, " -> ", a[..a.find("\r\n")]));
        let allow = a.find("Allow: ");
        if allow >= 0 { print(str("  ", a[allow..allow + a[allow..].find("\r\n")])); }
    } else {
        print(str(head, " -> today ", a[..a.find("\r\n")], ", A ", b[..b.find("\r\n")], ", B ",
                  c[..c.find("\r\n")]));
    }
}

fn put(n: i64) -> u8[>..] {
    var text = str("PUT /upload HTTP/1.1\r\nHost: x\r\nContent-Length: ", n, "\r\n\r\n");
    for i in n { text.push('a'); }
    return text;
}

fn slow(target: const u8[:], n: i64) {
    let box, e = http::mail_open(32, 256);
    http::exit_on_error(e);
    let lane = rest::lane_of<Jobs>(box, Use.Slow);
    let p = rest::play(lane, Jobs.Slow { n: n }) { u, a => run(u, a); };
    ask(str("GET ", target, " HTTP/1.1\r\nHost: x\r\n\r\n"), [rest::wake(p)]);
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
    slow("/slow", 6);
    ask("GET /reports/daily HTTP/1.1\r\nHost: x\r\nAuthorization: Bearer secret\r\n\r\n");
    ask("GET /reports/daily HTTP/1.1\r\nHost: x\r\n\r\n");
    ask("GET /reports/weekly HTTP/1.1\r\nHost: x\r\nAuthorization: Bearer secret\r\n\r\n");
    ask("POST /reports/daily HTTP/1.1\r\nHost: x\r\nAuthorization: Bearer secret\r\nContent-Length: 0\r\n\r\n");
    ask("GET /team/members HTTP/1.1\r\nHost: x\r\nAuthorization: Bearer secret\r\n\r\n");
    ask("GET /team/members HTTP/1.1\r\nHost: x\r\nAuthorization: Bearer wrong\r\n\r\n");
    ask("GET /team/nope HTTP/1.1\r\nHost: x\r\nAuthorization: Bearer secret\r\n\r\n");
    ask("GET /old/list HTTP/1.1\r\nHost: x\r\n\r\n");
    ask("GET /old/nope HTTP/1.1\r\nHost: x\r\n\r\n");
    ask("DELETE /old/list HTTP/1.1\r\nHost: x\r\n\r\n");
    slow("/old/slow", 3);
}
