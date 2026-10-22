// rest::routes leaves alone a request that waits: a route whose rest::body
// leaves to gather the body, run again with it whole, and one that asks a
// lane and answers at the reply's WAKE. Neither gets routes' 404 beside its
// answer.
import std;
import http from "github.com/kaitk/goose-http@v0.5.2";
import rest from "../../";
import expect from "../";

enum Jobs { Slow { n: i64 } }

enum Use { None, Slow }

struct St { use: Use = Use.None }

struct App { to: rest::Lane<Jobs, Use> }

fn resume(u: Use.None, cx) { rest::fail(cx, 500, "not_waiting"); }
fn resume(u: Use.Slow, cx) { resume(rest::job<Jobs>(cx), cx); }
fn resume(u: Jobs.Slow, cx) { rest::text(cx, 200, str("slow ", rest::answer<i64>(cx))); }

fn run(u: Jobs.Slow, a) { rest::reply_value(a, u.n * 7); }

fn handle(cx) {
    if rest::resumed(cx) {
        rest::on_reply(cx) { resume(cx.state.use, cx); };
        return;
    }
    rest::routes(cx) { cx =>
        rest::put(cx, "/upload") { rest::text(cx, 200, str(rest::body(cx).len)); };
        rest::get(cx, "/slow") { rest::ask(cx, cx.app.to, Jobs.Slow { n: 6 }); };
    };
}

fn main() {
    let box, e = http::mail_open(32, 256);
    http::exit_on_error(e);
    var app = App { to: rest::lane_of<Jobs>(box, Use.Slow) };
    var text = str("PUT /upload HTTP/1.1\r\nHost: x\r\nContent-Length: 100000\r\n\r\n");
    for i in 100000 { text.push('a'); }
    let up = rest::serve_one(text, app, St { .. }, []) { cx => handle(cx) };
    expect::same(expect::status_of(up), "HTTP/1.1 200 OK", "gathered body");
    expect::same(expect::body_of(up), "100000", "gathered body");
    let p = rest::play(app.to, Jobs.Slow { n: 6 }) { u, a => run(u, a); };
    let slow = rest::serve_one("GET /slow HTTP/1.1\r\nHost: x\r\n\r\n", app, St { .. }, [rest::wake(p)]) { cx => handle(cx) };
    expect::same(expect::status_of(slow), "HTTP/1.1 200 OK", "lane's reply");
    expect::same(expect::body_of(slow), "slow 42", "lane's reply");
    print("rest::routes with routes that wait: ok");
}
