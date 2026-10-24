// plod::try_ask: a job admitted, which the route then waits on as on
// plod::ask's; refused for a full lane box and for the gather budget, with
// nothing sent or promised, and the route answering its own way, or pausing
// and answering at the TIMEOUT; and plod::ask's own answers to the same
// refusals, as before.
import std;
import http from "github.com/kaitk/goose-http@v0.5.11";
import plod from "../../";
import expect from "../";

enum Looks { Up { n: i64 } }

// Look is the lane's mark, and Later a refused route's pause.
enum Use { None, Look, Later { why: i32 } }

struct St { use: Use = Use.None }

struct App { to: plod::Lane<Looks, Use> }

fn handle(cx) {
    if plod::resumed(cx) {
        plod::on_reply(cx) { resume(cx.state.use, cx); };
    } else {
        plod::route(cx) {
            if cx.req.target == "/ask" {
                plod::ask(cx, cx.app.to, Looks.Up { n: 4 });
            } else {
                let sent = plod::try_ask(cx, cx.app.to, Looks.Up { n: 4 });
                if sent != http::SENT {
                    if cx.req.target == "/later" {
                        plod::pause(cx, 5, Use.Later { why: sent });
                    } else {
                        plod::text(cx, 200, str("not asked: ", why(sent)));
                    }
                }
            }
        };
    }
}

fn why(sent: i32) -> const u8[:] {
    return if sent == plod::NO_BUDGET { "budget" } else if sent == http::FULL { "full" } else { "other" };
}

fn resume(u: Use.None, cx) { plod::fail(cx, 500, "not_waiting"); }
fn resume(u: Use.Look, cx) { resume(plod::job<Looks>(cx), cx); }
fn resume(u: Use.Later, cx) { plod::text(cx, 200, str("paused, then: ", why(u.why))); }
fn resume(u: Looks.Up, cx) { plod::text(cx, 200, str(u.n, " ", plod::answer<i64>(cx))); }

fn run(u: Looks.Up, a) { plod::reply_value(a, u.n * u.n); }

fn main() {
    // A box of two slots, which the test plays the lane of.
    let box, e = http::mail_open(2, 256);
    http::exit_on_error(e);
    var app = App { to: plod::lane_of<Looks>(box, Use.Look) };
    let four = plod::play(app.to, Looks.Up { n: 4 }) { u, a => run(u, a); };
    fn answer(target: const u8[:], wakes: const plod::Wake[:]) -> u8[>..] {
        return plod::serve_one(expect::request("GET", target), app, St { .. }, wakes) { cx => handle(cx); };
    }

    // Admitted, and answered with the reply; each leaves its job in the box,
    // and two fill it.
    print("admitted: ", expect::body_of(answer("/try", [plod::wake(four)])));
    expect::same(expect::body_of(answer("/try", [plod::wake(four)])), "4 16", "admitted again");

    // Refused for the full box: the route answers its own way, or pauses and
    // answers at the TIMEOUT, and nothing stays promised.
    print("box full: ", expect::body_of(answer("/try", [])), ", promised ", http::gather_promised);
    print("box full, paused: ", expect::body_of(answer("/later", [plod::Wake { timeout: true }])));
    let full = answer("/ask", []);
    print("box full, plod::ask: ", expect::status_of(full), " ", expect::body_of(full));
    assert(find(full, "Retry-After") < 0);
    let held = http::mail_take(box) { key, tag, bytes => assert(bytes.len > 0); };
    print("jobs in the box: ", held);

    // Refused for the gather budget, which can't promise the reply its most.
    http::gather_budget(plod::REPLY_LIMIT - 1);
    print("over the budget: ", expect::body_of(answer("/try", [])), ", promised ", http::gather_promised);
    print("over the budget, paused: ", expect::body_of(answer("/later", [plod::Wake { timeout: true }])));
    let over = answer("/ask", []);
    print("over the budget, plod::ask: ", expect::status_of(over), " ", expect::body_of(over));
    assert(find(over, "\r\nRetry-After: 1\r\n") >= 0);
    http::gather_budget(http::GATHER_BUDGET);
    let sent = http::mail_take(box) { key, tag, bytes => assert(bytes.len > 0); };
    print("jobs sent past the budget: ", sent);
    http::mail_close(box);
}
