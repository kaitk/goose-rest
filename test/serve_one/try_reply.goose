// plod::try_reply and plod::try_refuse: a reply and a refusal sent in one
// message, which the route reads as plod::reply_value's and plod::fail's;
// http::FULL at once from a full box, with nothing sent; http::TOO_LONG for
// a reply past one message, with nothing sent; http::STALE once the box is
// closed; the job answered every time, so plod::lane adds no refusal; and
// the same replies under plod::play.
import std;
import http from "github.com/kaitk/goose-http@v0.5.7";
import plod from "../../";
import expect from "../";

enum Looks { Up { n: i64 }, Missing { n: i64 }, Big { n: i64 } }

enum Use { None, Look }

struct St { use: Use = Use.None }

struct App { to: plod::Lane<Looks, Use> }

struct Wide { bytes: u8[..200] }

fn handle(cx) {
    if plod::resumed(cx) {
        plod::on_reply(cx) { resume(cx.state.use, cx); };
    } else {
        plod::route(cx) { plod::ask(cx, cx.app.to, Looks.Up { n: 4 }); };
    }
}

fn resume(u: Use.None, cx) { plod::fail(cx, 500, "not_waiting"); }
fn resume(u: Use.Look, cx) { resume(plod::job<Looks>(cx), cx); }
fn resume(u: Looks.Up, cx) { plod::text(cx, 200, str(u.n, " ", plod::answer<i64>(cx))); }
fn resume(u: Looks.Missing, cx) { plod::fail(cx, 500, "not_refused"); }
fn resume(u: Looks.Big, cx) { plod::fail(cx, 500, "not_too_long"); }

var results: i32[>..] = [];

fn run(u: Looks.Up, a) { results.push(plod::try_reply(a, u.n * u.n)); }
fn run(u: Looks.Missing, a) { results.push(plod::try_refuse(a, 404, "not_found")); }
fn run(u: Looks.Big, a) { results.push(plod::try_reply(a, Wide { bytes: "" })); }

fn name(r: i32) -> const u8[:] {
    return if r == http::SENT { "sent" } else if r == http::FULL { "full" } else if r == http::STALE {
        "stale"
    } else if r == http::TOO_LONG { "too long" } else { "other" };
}

// The job run as plod::lane runs it, replying to box, and what it returned.
fn run_on(box: http::Box, job: Looks) -> const u8[:] {
    var a = plod::Asked<Looks> { reply: http::address(box, 1), piece: 64, job: job };
    plod::run_job(&a) { u, a => run(u, a); };
    return name(results[results.len - 1]);
}

fn main() {
    let lane_box, e = http::mail_open(16, 256);
    http::exit_on_error(e);
    var app = App { to: plod::lane_of<Looks>(lane_box, Use.Look) };
    fn answer(wakes: const plod::Wake[:]) -> u8[>..] {
        return plod::serve_one(expect::request("GET", "/"), app, St { .. }, wakes) { cx => handle(cx); };
    }

    // A box of two slots, the worker's: a reply and a refusal fill it, and a
    // third finds it full at once, with nothing sent. A reply past one
    // message is refused before the box.
    let box, e2 = http::mail_open(2, 64);
    http::exit_on_error(e2);
    print("reply: ", run_on(box, Looks.Up { n: 4 }));
    print("refusal: ", run_on(box, Looks.Missing { n: 1 }));
    print("box full: ", run_on(box, Looks.Up { n: 5 }));
    print("past one message: ", run_on(box, Looks.Big { n: 1 }));

    // The route reads them as plod::reply_value's and plod::fail's.
    let n = http::mail_take(box) { key, tag, bytes =>
        let r = answer([plod::Wake { data: bytes, tag: tag }]);
        print("answered: ", expect::status_of(r), " ", expect::body_of(r));
    };
    print("messages in the box: ", n);
    http::mail_take(lane_box) { key, tag, bytes => };
    http::mail_close(box);
    print("box closed: ", run_on(box, Looks.Up { n: 6 }));

    // Under plod::play, as plod::reply_value's.
    let played = plod::play(app.to, Looks.Up { n: 7 }) { u, a => run(u, a); };
    print("played: ", expect::body_of(answer([plod::wake(played)])));
    let refused = plod::play(app.to, Looks.Missing { n: 1 }) { u, a => run(u, a); };
    let status, code = plod::refusal(refused);
    print("played refusal: ", status, " ", code);
    http::mail_close(lane_box);
}
