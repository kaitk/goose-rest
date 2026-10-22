// A handler behind goose-rest's middleware, rest::timed, rest::cors, block
// scopes, and rest::bearer, around rest::get and a failure two calls below
// it, written out under /v1 and as a stack calling a stack under /v2:
// member_routes calls signed_in_routes, and the token passes through both
// blocks. Inside rest::routes, cors and timed run their block in
// rest::scoped, a route of its own inside the request's one route.
// scripts/test.sh compiles it with -O2 and checks that the C holds no
// function of the middleware's, the routes', the scopes', the stacks', or the
// helpers that fail: all of it is inlined into handle, each early answer a jump, as in
// spike 04. handle itself stays a function, as a function given a large block
// does (docs/goose-findings.md).
import std;
import http from "github.com/kaitk/goose-http@b5f82a2d302b01c83e6d5073641720238590af22";
import rest from "../";

struct Item { id: i64, owner: i64 }

fn format(out: u8[>..]&, it: const Item&) { format(out, "{\"id\":", it.id, ",\"owner\":", it.owner, "}"); }

fn find_item(cx, id: i64) -> Item {
    guard id > 0 else { rest::fail(cx, 404, "item_not_found"); }
    return Item { id: id, owner: id % 3 };
}

fn load(cx, user: i64, id: i64) -> Item {
    let it = find_item(cx, id);
    guard it.owner == user else { rest::fail(cx, 403, "not_owner"); }
    return it;
}

inline fn signed_in_routes<F>(cx) {
    rest::bearer(cx) { token => F(token); };
}

inline fn member_routes<F>(cx) {
    rest::timed(cx, false) {
        rest::cors(cx, rest::Cors { origins: "https://a.example", .. }) {
            signed_in_routes(cx) { token => F(token); };
        };
    };
}

fn handle(cx) {
    rest::routes(cx) { cx =>
        rest::scope(cx, "/v1") {
            rest::cors(cx, rest::Cors { origins: "https://a.example", .. }) {
                rest::bearer(cx) { token =>
                    let user = rest::int_of(cx, token, "token");
                    rest::get(cx, "/items/:id") { rest::json(cx, 200, load(cx, user, rest::param_int(cx, "id"))); };
                };
            };
        };
        rest::scope(cx, "/v2") {
            member_routes(cx) { token =>
                let user = rest::int_of(cx, token, "token");
                rest::get(cx, "/items/:id") { rest::json(cx, 200, load(cx, user, rest::param_int(cx, "id"))); };
            };
        };
    };
}

fn main() {
    var out: u8[>..] = [];
    for target in ["/v1/items/4", "/v1/items/0", "/v1/items/5", "/v2/items/4", "/v2/items/0", "/v2/items/5"] {
        let text = str("GET ", target, " HTTP/1.1\r\nHost: x\r\nOrigin: https://a.example\r\n",
                       "Authorization: Bearer 1\r\n\r\n");
        let req, status = http::parse(text);
        var keep = true;
        var st = http::Stream { .. };
        var state = rest::NoState { .. };
        var scratch: u8[>..] = [];
        var app = rest::NoState { .. };
        var none = rest::NoRouter { .. };
        var cx = rest::Cx<rest::NoState, rest::NoState, rest::NoRouter> { req: req, body: "", out: http::Reply {
                                           buf: out, common: "", keep_alive: keep, minor: 1, head: false, stream: st },
                                           state: state, app: app, scratch: scratch, router: none };
        handle(cx);
    }
    print(out);
}
