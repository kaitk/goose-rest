// plod::serve_one with a route that asks a lane, given what the lane's run
// replies under plod::play: a value, whole and in pieces, a value past the
// reply limit the route asked with, an ask the gather budget can't promise
// its reply, a relay in one piece and in several with the job in front,
// a refusal from a plod::fail on the lane, a run that replies nothing, two
// waits in turn, whole and in pieces, a timeout, and a wait with no wake
// left.
import std;
import http from "github.com/kaitk/goose-http@ebb4238728179e82140550af50e5bab1a7e0dab2";
import plod from "../../";
import expect from "../";

// The lane's jobs.
enum Echoes {
    Value { n: i64 },
    Text { s: u8[..32] },
    Refused { status: i32 },
    Silent,
    Twice { n: i64 },
    Wide { n: i64 },
}

// A value wider than the job.
struct Row { n: i64, square: i64, name: u8[..24] }

enum Use { None, Echo }

struct St { use: Use = Use.None }

// most is the reply limit of /narrow's ask.
struct App { to: plod::Lane<Echoes, Use>, most: i64 = plod::REPLY_LIMIT }

// What the lane's thread owns: here, what each job adds.
struct Adder { by: i64 }

fn handle(cx) {
    if plod::resumed(cx) {
        plod::on_reply(cx) { resume(cx.state.use, cx); };
    } else {
        plod::route(cx) {
            let path = cx.req.target;
            if path == "/value" {
                plod::ask(cx, cx.app.to, Echoes.Value { n: 40 });
            } else if path == "/text" {
                plod::ask(cx, cx.app.to, Echoes.Text { s: "abcdefghij" });
            } else if path == "/refused" {
                plod::ask(cx, cx.app.to, Echoes.Refused { status: 409 });
            } else if path == "/silent" {
                plod::ask(cx, cx.app.to, Echoes.Silent);
            } else if path == "/wide" {
                plod::ask(cx, cx.app.to, Echoes.Wide { n: 7 });
            } else if path == "/narrow" {
                plod::ask(cx, cx.app.to, Echoes.Wide { n: 7 }, 5000, cx.app.most);
            } else {
                plod::ask(cx, cx.app.to, Echoes.Twice { n: 1 });
            }
        };
    }
}

fn resume(u: Use.None, cx) { plod::fail(cx, 500, "not_waiting"); }
fn resume(u: Use.Echo, cx) { resume(plod::job<Echoes>(cx), cx); }

// On the lane, each job's run.
fn run(u: Echoes.Value, d: Adder&, a) { plod::reply_value(a, u.n + d.by); }
fn run(u: Echoes.Text, d: Adder&, a) { plod::reply(a, u.s); }
fn run(u: Echoes.Refused, d: Adder&, a) { plod::fail(a, u.status, "refused_here"); }
fn run(u: Echoes.Silent, d: Adder&, a) {}
fn run(u: Echoes.Twice, d: Adder&, a) { plod::reply_value(a, u.n * 10); }
fn run(u: Echoes.Wide, d: Adder&, a) { plod::reply_value(a, Row { n: u.n, square: u.n * u.n, name: "seven" }); }

// On the worker, each job's resume, given the job back.
fn resume(u: Echoes.Value, cx) { plod::text(cx, 200, str(u.n, " ", plod::answer<i64>(cx))); }
fn resume(u: Echoes.Text, cx) { plod::relay(cx, 200, "text/plain"); }
fn resume(u: Echoes.Refused, cx) { plod::fail(cx, 500, "not_reached"); }
fn resume(u: Echoes.Silent, cx) { plod::fail(cx, 500, "not_reached"); }

fn resume(u: Echoes.Wide, cx) {
    let r = plod::answer<Row>(cx);
    plod::text(cx, 200, str("wide ", u.n, ": ", r.square, " ", r.name));
}

// Two waits in turn: the second asks again with the first's answer, until
// it's past 100.
fn resume(u: Echoes.Twice, cx) {
    let n = plod::answer<i64>(cx);
    if n > 100 { plod::text(cx, 200, str(n)); } else { plod::ask(cx, cx.app.to, Echoes.Twice { n: n }); }
}

fn main() {
    let box, e = http::mail_open(32, 256);
    http::exit_on_error(e);
    // A lane of the test's own box, and no thread: the test plays it.
    var app = App { to: plod::lane_of<Echoes>(box, Use.Echo) };
    var d = Adder { by: 2 };
    fn answer(target: const u8[:], wakes: const plod::Wake[:], cfg: http::Config = http::Config { .. }) -> u8[>..] {
        return plod::serve_one(expect::request("GET", target), app, St { .. }, wakes, cfg) { cx => handle(cx); };
    }

    // An answer, read with the job it came back with.
    let value = plod::play(app.to, Echoes.Value { n: 40 }) { u, a => run(u, d, a); };
    expect::same(expect::body_of(answer("/value", [plod::wake(value)])), "40 42", "a value");

    // A reply relayed whole, and in pieces, the job's 4 bytes of length and
    // its image first, which the first piece holds with the reply's start:
    // relay skips them.
    let text = plod::play(app.to, Echoes.Text { s: "abcdefghij" }) { u, a => run(u, d, a); };
    expect::same(answer("/text", [plod::wake(text)]),
                 "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 10\r\n\r\nabcdefghij", "one piece");
    let small = http::Config { mail_size: (text.data.len - 4) as i32, .. };
    expect::same(answer("/text", [plod::wake(text)], small),
                 "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\nContent-Type: text/plain\r\n\r\n6\r\nabcdef\r\n4\r\nghij\r\n0\r\n\r\n",
                 "several pieces");

    // A value in pieces is collected whole before the resume runs, which
    // dispatches on the job at its front: in two pieces, and in pieces of
    // the job's size, the job alone in the first.
    let tiny = http::Config { mail_size: (value.data.len - 1) as i32, .. };
    expect::same(expect::body_of(answer("/value", [plod::wake(value)], tiny)), "40 42", "a value in two pieces");
    let wide = plod::play(app.to, Echoes.Wide { n: 7 }) { u, a => run(u, d, a); };
    let row = plod::value_bytes(Row { n: 7, square: 49, name: "seven" });
    let thirds = http::Config { mail_size: (wide.data.len - row.len) as i32, .. };
    expect::same(expect::body_of(answer("/wide", [plod::wake(wide)], thirds)), "wide 7: 49 seven", "a value after the job");
    print("a value of ", wide.data.len, " bytes in pieces of ", thirds.mail_size);

    // A value past the reply limit the route asked with fails the route with
    // 502 reply_too_large.
    app.most = wide.data.len - 1;
    let past = answer("/narrow", [plod::wake(wide)], thirds);
    print("past its limit: ", expect::status_of(past), " ", expect::body_of(past));
    app.most = plod::REPLY_LIMIT;
    // An ask the worker's gather budget can't promise its reply limit fails
    // with 503 before its job is sent.
    http::gather_budget(plod::REPLY_LIMIT - 1);
    let over = plod::serve_one(expect::request("GET", "/wide"), app, St { .. }, [plod::wake(wide)], thirds) { cx =>
        handle(cx);
    };
    http::gather_budget(http::GATHER_BUDGET);
    print("over the budget: ", expect::status_of(over), " ", expect::body_of(over));
    assert(find(over, "\r\nRetry-After: 1\r\n") >= 0);

    // A plod::fail on the lane fails the route with its status and code,
    // before the resume runs.
    let refused = plod::play(app.to, Echoes.Refused { status: 409 }) { u, a => run(u, d, a); };
    let status, code = plod::refusal(refused);
    print("refusal: ", status, " ", code);
    let out = answer("/refused", [plod::wake(refused)]);
    print("refused: ", expect::status_of(out), " ", expect::body_of(out));

    // A run that neither replies nor fails gets the route 500 no_reply.
    let silent = plod::play(app.to, Echoes.Silent) { u, a => run(u, d, a); };
    print("silent: ", expect::body_of(answer("/silent", [plod::wake(silent)])));

    // Waits in turn.
    let first = plod::play(app.to, Echoes.Twice { n: 1 }) { u, a => run(u, d, a); };
    let second = plod::play(app.to, Echoes.Twice { n: 10 }) { u, a => run(u, d, a); };
    let third = plod::play(app.to, Echoes.Twice { n: 100 }) { u, a => run(u, d, a); };
    expect::same(expect::body_of(answer("/twice", [plod::wake(first), plod::wake(second), plod::wake(third)])), "1000", "three waits");
    let job_size = http::Config { mail_size: (first.data.len - plod::value_bytes(10).len) as i32, .. };
    expect::same(expect::body_of(answer("/twice", [plod::wake(first), plod::wake(second), plod::wake(third)], job_size)),
                 "1000", "three waits in pieces");

    // A job that doesn't fit one message of the reply with its length fails
    // the route with 500 job_too_large before the job is sent: the reply
    // would carry it at its front.
    let short = http::Config { mail_size: job_size.mail_size - 1, .. };
    let too_large = answer("/twice", [plod::wake(first)], short);
    print("in pieces of ", short.mail_size, ": ", expect::status_of(too_large), " ", expect::body_of(too_large));
    expect::same(expect::status_of(answer("/twice", [plod::wake(first)])), "HTTP/1.1 500 Internal Server Error",
                 "no wake left");

    // The wait's end instead of a reply.
    expect::same(answer("/value", [plod::Wake { timeout: true }]),
                 "HTTP/1.1 504 Gateway Timeout\r\nContent-Type: application/json\r\nContent-Length: 19\r\n\r\n{\"error\":\"timeout\"}",
                 "timeout");
    // No room to wait, which goose-http says at once: a refusal at admission.
    expect::same(answer("/value", [plod::Wake { timeout: true, early: true }]),
                 str("HTTP/1.1 503 Service Unavailable\r\nRetry-After: 1\r\nContent-Type: application/json\r\n",
                     "Content-Length: 23\r\n\r\n{\"error\":\"unavailable\"}"),
                 "no room");

    // Each ask sent its job to the box, read as the lane reads it.
    var jobs: u8[>..] = [];
    let n = http::mail_take(box) { key, tag, bytes =>
        plod::lane_job(plod::Jobs<Echoes> { .. }, bytes) { u, a => format(jobs, u, "\n"); };
    };
    print(jobs, "jobs: ", n);
    http::mail_close(box);
}
