// rest::serve_one with a route that asks a lane, given what the lane's run
// replies under rest::play: a value, a relay in one piece and in several with
// the job in front, a refusal from a rest::fail on the lane, a run that
// replies nothing, two waits in turn, a timeout, and a wait with no wake
// left; and the request state once the route has answered.
import std;
import http from "github.com/kaitk/goose-http@ff18ecc766651a4ff0143361413c81f33873c8b2";
import rest from "../../";
import expect from "../";

// The lane's jobs.
enum Echoes {
    Value { n: i64 },
    Text { s: u8[..32] },
    Refused { status: i32 },
    Silent,
    Twice { n: i64 },
}

enum Use { None, Echo }

struct St { use: Use = Use.None }

struct App { to: rest::Lane<Echoes, Use> }

// What the lane's thread owns: here, what each job adds.
struct Adder { by: i64 }

fn handle(cx) {
    if rest::resumed(cx) {
        rest::on_reply(cx) { resume(cx.state.use, cx); };
    } else {
        rest::route(cx) {
            let path = cx.req.target;
            if path == "/value" {
                rest::ask(cx, cx.app.to, Echoes.Value { n: 40 });
            } else if path == "/text" {
                rest::ask(cx, cx.app.to, Echoes.Text { s: "abcdefghij" });
            } else if path == "/refused" {
                rest::ask(cx, cx.app.to, Echoes.Refused { status: 409 });
            } else if path == "/silent" {
                rest::ask(cx, cx.app.to, Echoes.Silent);
            } else {
                rest::ask(cx, cx.app.to, Echoes.Twice { n: 1 });
            }
        };
    }
}

fn resume(u: Use.None, cx) { rest::fail(cx, 500, "not_waiting"); }
fn resume(u: Use.Echo, cx) { resume(rest::job<Echoes>(cx), cx); }

// On the lane, each job's run.
fn run(u: Echoes.Value, d: Adder&, a) { rest::reply_value(a, u.n + d.by); }
fn run(u: Echoes.Text, d: Adder&, a) { rest::reply(a, u.s); }
fn run(u: Echoes.Refused, d: Adder&, a) { rest::fail(a, u.status, "refused_here"); }
fn run(u: Echoes.Silent, d: Adder&, a) {}
fn run(u: Echoes.Twice, d: Adder&, a) { rest::reply_value(a, u.n * 10); }

// On the worker, each job's resume, given the job back.
fn resume(u: Echoes.Value, cx) { rest::text(cx, 200, str(u.n, " ", rest::answer<i64>(cx))); }
fn resume(u: Echoes.Text, cx) { rest::relay(cx, 200, "text/plain"); }
fn resume(u: Echoes.Refused, cx) { rest::fail(cx, 500, "not_reached"); }
fn resume(u: Echoes.Silent, cx) { rest::fail(cx, 500, "not_reached"); }

// Two waits in turn: the second asks again with the first's answer, until
// it's past 100.
fn resume(u: Echoes.Twice, cx) {
    let n = rest::answer<i64>(cx);
    if n > 100 { rest::text(cx, 200, str(n)); } else { rest::ask(cx, cx.app.to, Echoes.Twice { n: n }); }
}

fn main() {
    let box, e = http::mail_open(16, 256);
    http::exit_on_error(e);
    // A lane of the test's own box, and no thread: the test plays it.
    var app = App { to: rest::lane_of<Echoes>(box, Use.Echo) };
    var d = Adder { by: 2 };
    var st = St { .. };
    fn answer(target: const u8[:], wakes: const rest::Wake[:], cfg: http::Config = http::Config { .. }) -> u8[>..] {
        return rest::serve_one(expect::request("GET", target), app, St { .. }, wakes, cfg) { cx =>
            handle(cx);
            st = cx.state;
        };
    }

    // An answer, read with the job it came back with.
    let value = rest::play(app.to, Echoes.Value { n: 40 }) { u, a => run(u, d, a); };
    expect::same(expect::body_of(answer("/value", [rest::wake(value)])), "40 42", "a value");
    print("then: ", st.use);

    // A reply relayed whole, and in pieces of 8 bytes, the job's 2 bytes of
    // length and its image first: relay skips them.
    let text = rest::play(app.to, Echoes.Text { s: "abcdefghij" }) { u, a => run(u, d, a); };
    expect::same(answer("/text", [rest::wake(text)]),
                 "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 10\r\n\r\nabcdefghij", "one piece");
    let small = http::Config { mail_size: (text.data.len - 4) as i32, .. };
    expect::same(answer("/text", [rest::wake(text)], small),
                 "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\nContent-Type: text/plain\r\n\r\n6\r\nabcdef\r\n4\r\nghij\r\n0\r\n\r\n",
                 "several pieces");
    print("relayed in pieces, then: ", st.use);

    // A value can't be read from pieces.
    let tiny = http::Config { mail_size: (value.data.len - 1) as i32, .. };
    expect::same(expect::body_of(answer("/value", [rest::wake(value)], tiny)), "{\"error\":\"bad_reply\"}", "a value in pieces");

    // A rest::fail on the lane fails the route with its status and code,
    // before the resume runs.
    let refused = rest::play(app.to, Echoes.Refused { status: 409 }) { u, a => run(u, d, a); };
    let status, code = rest::refusal(refused);
    print("refusal: ", status, " ", code);
    let out = answer("/refused", [rest::wake(refused)]);
    print("refused: ", expect::status_of(out), " ", expect::body_of(out));
    print("then: ", st.use);

    // A run that neither replies nor fails gets the route 500 no_reply.
    let silent = rest::play(app.to, Echoes.Silent) { u, a => run(u, d, a); };
    print("silent: ", expect::body_of(answer("/silent", [rest::wake(silent)])));

    // Two waits in turn: the mark stays between them.
    let first = rest::play(app.to, Echoes.Twice { n: 1 }) { u, a => run(u, d, a); };
    let second = rest::play(app.to, Echoes.Twice { n: 10 }) { u, a => run(u, d, a); };
    let third = rest::play(app.to, Echoes.Twice { n: 100 }) { u, a => run(u, d, a); };
    expect::same(expect::body_of(answer("/twice", [rest::wake(first), rest::wake(second), rest::wake(third)])), "1000", "three waits");
    print("then: ", st.use);
    expect::same(expect::status_of(answer("/twice", [rest::wake(first)])), "HTTP/1.1 500 Internal Server Error",
                 "no wake left");
    print("no wake left, then: ", st.use);

    // The wait's end instead of a reply.
    expect::same(answer("/value", [rest::Wake { timeout: true }]),
                 "HTTP/1.1 504 Gateway Timeout\r\nContent-Type: application/json\r\nContent-Length: 19\r\n\r\n{\"error\":\"timeout\"}",
                 "timeout");

    // Each ask sent its job to the box, read as the lane reads it.
    var jobs: u8[>..] = [];
    let n = http::mail_take(box) { key, tag, bytes =>
        rest::lane_job<Echoes>(bytes) { u, a => format(jobs, u, "\n"); };
    };
    print(jobs, "jobs: ", n);
    http::mail_close(box);
}
