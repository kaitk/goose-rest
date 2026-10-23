// plod::routes leaves alone a request that waits: a route whose plod::body
// leaves to gather the body, run again with it whole, and one that asks a
// lane and answers at the reply's WAKE. Neither gets routes' 404 beside its
// answer.
import std;
import http from "github.com/kaitk/goose-http@v0.5.7";
import plod from "../../";
import expect from "../";

enum Jobs { Slow { n: i64 } }

enum Use { None, Slow }

struct St { use: Use = Use.None }

struct App { to: plod::Lane<Jobs, Use> }

fn resume(u: Use.None, cx) { plod::fail(cx, 500, "not_waiting"); }
fn resume(u: Use.Slow, cx) { resume(plod::job<Jobs>(cx), cx); }
fn resume(u: Jobs.Slow, cx) { plod::text(cx, 200, str("slow ", plod::answer<i64>(cx))); }

fn run(u: Jobs.Slow, a) { plod::reply_value(a, u.n * 7); }

fn handle(cx) {
    if plod::resumed(cx) {
        plod::on_reply(cx) { resume(cx.state.use, cx); };
        return;
    }
    plod::routes(cx) { cx =>
        plod::put(cx, "/upload") { plod::text(cx, 200, str(plod::body(cx).len)); };
        plod::get(cx, "/slow") { plod::ask(cx, cx.app.to, Jobs.Slow { n: 6 }); };
    };
}

fn main() {
    let box, e = http::mail_open(32, 256);
    http::exit_on_error(e);
    var app = App { to: plod::lane_of<Jobs>(box, Use.Slow) };
    var text = str("PUT /upload HTTP/1.1\r\nHost: x\r\nContent-Length: 100000\r\n\r\n");
    for i in 100000 { text.push('a'); }
    let up = plod::serve_one(text, app, St { .. }, []) { cx => handle(cx) };
    expect::same(expect::status_of(up), "HTTP/1.1 200 OK", "gathered body");
    expect::same(expect::body_of(up), "100000", "gathered body");
    let p = plod::play(app.to, Jobs.Slow { n: 6 }) { u, a => run(u, a); };
    let slow = plod::serve_one("GET /slow HTTP/1.1\r\nHost: x\r\n\r\n", app, St { .. }, [plod::wake(p)]) { cx => handle(cx) };
    expect::same(expect::status_of(slow), "HTTP/1.1 200 OK", "lane's reply");
    expect::same(expect::body_of(slow), "slow 42", "lane's reply");
    print("plod::routes with routes that wait: ok");
}
