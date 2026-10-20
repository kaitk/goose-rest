// The sizes a reply's job and a refusal's code take: a job whose image is
// longer than 64 KB, which the reply's 4-byte length carries back, in one
// message and with the value after it in a second, and in messages too
// small for it; and a refusal's code longer than a message, which rest::play
// gives whole and serve_one cuts to fit, as the lane does on the real path.
import std;
import http from "github.com/kaitk/goose-http@v0.4.2";
import rest from "../../";
import expect from "../";

// A job wider than 65,535 bytes.
enum Bigs { Blob { n: i64, s: u8[..70000] } }

// A job its lane refuses with a code of n bytes.
enum Codes { Refuse { n: i64 } }

enum Use { None, Big, Code }

struct St { use: Use = Use.None }

struct App { bigs: rest::Lane<Bigs, Use>, codes: rest::Lane<Codes, Use> }

fn blob() -> Bigs {
    var s: u8[..70000] = [];
    for i in 70000 { s.push('a' + (i % 26) as u8); }
    return Bigs.Blob { n: 3, s: s };
}

fn handle(cx) {
    if rest::resumed(cx) {
        rest::on_reply(cx) { resume(cx.state.use, cx); };
    } else {
        rest::route(cx) {
            if cx.req.target == "/big" { rest::ask(cx, cx.app.bigs, blob()); } else { rest::ask(cx, cx.app.codes, Codes.Refuse { n: 300 }); }
        };
    }
}

fn resume(u: Use.None, cx) { rest::fail(cx, 500, "not_waiting"); }
fn resume(u: Use.Big, cx) { resume(rest::job<Bigs>(cx), cx); }
fn resume(u: Use.Code, cx) { resume(rest::job<Codes>(cx), cx); }

fn resume(u: Bigs.Blob, cx) {
    rest::text(cx, 200, str(u.n, " ", u.s.len, " ", u.s[69999..], " ", rest::answer<i64>(cx)));
}

fn resume(u: Codes.Refuse, cx) { rest::fail(cx, 500, "not_reached"); }

fn run(u: Bigs.Blob, a) { rest::reply_value(a, u.s.len + u.n); }

fn run(u: Codes.Refuse, a) {
    var code: u8[>..] = [];
    for i in u.n { code.push('a' + (i % 26) as u8); }
    rest::fail(a, 409, code);
}

fn main() {
    let big_box, e = http::mail_open(4, 1 << 17);
    http::exit_on_error(e);
    let code_box, e2 = http::mail_open(4, 256);
    http::exit_on_error(e2);
    var app = App { bigs: rest::lane_of<Bigs>(big_box, Use.Big), codes: rest::lane_of<Codes>(code_box, Use.Code) };
    fn answer(target: const u8[:], wakes: const rest::Wake[:], cfg: http::Config) -> u8[>..] {
        return rest::serve_one(expect::request("GET", target), app, St { .. }, wakes, cfg) { cx => handle(cx); };
    }

    // The job back whole, in one message, and with the value in a second.
    let p = rest::play(app.bigs, blob()) { u, a => run(u, a); };
    let head = p.data.len - rest::value_bytes(70003).len;
    print("a job's head of ", head, " bytes");
    let one = answer("/big", [rest::wake(p)], http::Config { mail_size: 1 << 17, .. });
    print("in one message: ", expect::status_of(one), " ", expect::body_of(one));
    let two = answer("/big", [rest::wake(p)], http::Config { mail_size: head as i32, .. });
    print("the value after it: ", expect::status_of(two), " ", expect::body_of(two));
    let short = answer("/big", [rest::wake(p)], http::Config { mail_size: (head - 1) as i32, .. });
    print("in messages of ", head - 1, ": ", expect::status_of(short), " ", expect::body_of(short));

    // A code longer than a message: play keeps it whole, and serve_one cuts
    // it to the message, as the lane cuts it to the size the ask gave.
    let small = http::Config { mail_size: 64, .. };
    let played = rest::play(app.codes, Codes.Refuse { n: 300 }) { u, a => run(u, a); };
    let status, code = rest::refusal(played);
    print("played: ", status, ", a code of ", code.len, " bytes");
    let from_play = answer("/code", [rest::wake(played)], small);
    let reply_box, e3 = http::mail_open(4, 64);
    http::exit_on_error(e3);
    var asked = rest::Asked<Codes> { reply: http::address(reply_box, 1), piece: 64, job: Codes.Refuse { n: 300 } };
    rest::run_job(&asked) { u, a => run(u, a); };
    var sent: u8[>..] = [];
    var sent_tag: i32 = 0;
    let n = http::mail_take(reply_box) { key, tag, bytes =>
        sent.append(bytes);
        sent_tag = tag;
    };
    let from_lane = answer("/code", [rest::Wake { data: sent, tag: sent_tag }], small);
    expect::same(from_play, from_lane, "played as sent");
    print("the lane sent ", n, " message of ", sent.len, " bytes; both answer: ", expect::status_of(from_play), " ",
          expect::body_of(from_play));
    http::mail_close(reply_box);
    http::mail_close(code_box);
    http::mail_close(big_box);
}
