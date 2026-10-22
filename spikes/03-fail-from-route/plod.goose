namespace plod;

import std;

struct Cx { path: const u8[:], status: i32, body: u8[>..] }

struct Failure { status: i32, code: u8[..32] }

fn route<F>(cx: Cx&) -> Failure {
    F();
    return Failure { status: 0, code: [] };
}

fn fail(cx: Cx&, status: i32, code: const u8[:]) {
    return Failure { status: status, code: code } from route;
}

fn serve<F>(cx: Cx&) {
    let f = route(cx) { F() };
    if f.status != 0 {
        cx.status = f.status;
        cx.body.clear();
        format(cx.body, "{\"error\":\"", f.code, "\"}");
    }
}
