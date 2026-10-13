// A handler with two middleware blocks around rest::route, and a failure two
// calls below it. scripts/test.sh compiles it with -O2 and checks that the C
// holds no function of the handler's, the blocks', or route's: all of it is
// inlined into main, each early answer a jump, as in spike 04.
import std;
import http from "github.com/kaitk/goose-http@cfb9c02bd8cd1d841eaf9d140ff0dbd96bb3bcf8";
import rest from "../";

// Answers 403 unless the request has an Origin field, as a CORS check would.
fn with_origin<F>(cx) {
    let origin, found = http::field_of(cx.req, "Origin");
    guard found && origin.len > 0 else { rest::text(cx, 403, "origin"); return; }
    F();
}

// Hands the block the session's user, or answers 401.
fn with_user<F>(cx) {
    let raw, found = http::cookie_of(cx.req, "session");
    guard found else { rest::text(cx, 401, "unauthenticated"); return; }
    let user, ok = parse_int(raw);
    guard ok else { rest::text(cx, 401, "unauthenticated"); return; }
    F(user);
}

struct Item { id: i64, owner: i64 }

fn format(out: u8[>..]&, it: const Item&) { format(out, "{\"id\":", it.id, ",\"owner\":", it.owner, "}"); }

fn find(cx, id: i64) -> Item {
    guard id > 0 else { rest::fail(cx, 404, "item_not_found"); }
    return Item { id: id, owner: id % 3 };
}

fn load(cx, user: i64, id: i64) -> Item {
    let it = find(cx, id);
    guard it.owner == user else { rest::fail(cx, 403, "not_owner"); }
    return it;
}

fn handle(cx, id: i64) {
    with_origin(cx) {
        with_user(cx) { user =>
            rest::route(cx) { rest::json(cx, 200, load(cx, user, id)); };
        };
    };
}

fn main() {
    let text = "GET /items/4 HTTP/1.1\r\nHost: x\r\nOrigin: https://a.example\r\nCookie: session=1\r\n\r\n";
    let req, status = http::parse(text);
    var out: u8[>..] = [];
    var keep = true;
    var st = http::Stream { .. };
    var state = rest::NoState { .. };
    var cx = rest::Cx<rest::NoState> { req: req, body: "", out: http::Reply { buf: out, common: "",
                                       keep_alive: keep, minor: 1, head: false, stream: st }, state: state };
    for id in [4, 0, 5] { handle(cx, id); }
    print(status, "\n", out);
}
