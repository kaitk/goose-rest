// What rest::cors keeps for an answer at a later call is promised from the
// worker's gather budget: a route that reads its body in pieces behind it,
// on a budget that can't hold the fields, gets 503 with them at its
// request, and its case function CLOSED; on a budget that can, the answer
// at the END has them.
import std;
import http from "github.com/kaitk/goose-http@e128cb39d82c0fa45280452b1c434a55384e14d7";
import rest from "../../";
import expect from "../";

enum Use { None, Up }

struct St { use: Use = Use.None, size: i64 = 0 }

struct App { log: u8[>..]& }

fn resume(u: Use.None, cx) { rest::fail(cx, 500, "not_waiting"); }

fn resume(u: Use.Up, cx) {
    if cx.kind == http::BODY {
        cx.state.size += cx.body.len;
    } else if cx.kind == http::END {
        rest::text(cx, 200, str(cx.state.size));
    } else if cx.kind == http::CLOSED {
        cx.app.log.append("CLOSED");
    }
}

fn answer(budget: i64, log: u8[>..]&) -> u8[>..] {
    var text = str("POST /up HTTP/1.1\r\nHost: x\r\nOrigin: https://a.example\r\nContent-Length: 600\r\n\r\n");
    for i in 600 { text.push('a'); }
    var app = App { log: log };
    let cfg = http::Config { max_head: 512, .. };
    http::gather_budget(budget);
    let out = rest::serve_one(text, app, St { .. }, cfg) { cx =>
        if rest::resumed(cx) {
            resume(cx.state.use, cx);
        } else {
            rest::cors(cx, rest::Cors { origins: "https://a.example" }) { rest::body_in_pieces(cx, 1 << 20, Use.Up); };
        }
    };
    http::gather_budget(http::GATHER_BUDGET);
    return out;
}

fn main() {
    var log: u8[>..] = [];
    let refused = answer(10, log);
    expect::same(expect::status_of(refused), "HTTP/1.1 503 Service Unavailable", "a budget too small");
    assert(find(refused, "\r\nRetry-After: 1\r\n") >= 0);
    assert(find(refused, "\r\nAccess-Control-Allow-Origin: https://a.example\r\n") >= 0);
    expect::same(log, "CLOSED", "the route's case function");
    assert(http::gather_promised == 0);
    var none: u8[>..] = [];
    let kept = answer(http::GATHER_BUDGET, none);
    expect::same(expect::body_of(kept), "600", "a budget that holds them");
    assert(find(kept, "\r\nAccess-Control-Allow-Origin: https://a.example\r\n") >= 0 && none.len == 0);
    assert(http::gather_promised == 0);
    print("the fields kept for a later answer, against the budget: ok");
}
