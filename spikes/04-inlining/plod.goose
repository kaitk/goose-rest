namespace plod;

import std;

struct Cx { cookie: const u8[:], origin: const u8[:], status: i32, body: u8[>..] }
struct Session { user: i64 }
struct Failure { status: i32, code: u8[..32] }

fn answer(cx: Cx&, status: i32, text: const u8[:]) {
    cx.status = status;
    cx.body.clear();
    cx.body.append(text);
}

fn with_cors<F>(cx: Cx&) {
    guard cx.origin.len == 0 || cx.origin == "https://a.example" else {
        answer(cx, 403, "origin");
        return;
    }
    F();
}

fn with_auth<F>(cx: Cx&) {
    guard cx.cookie == "ok" else { answer(cx, 401, "unauthenticated"); return; }
    F(Session { user: 7 });
}

fn with_role<F>(cx: Cx&, s: Session) {
    guard s.user == 7 else { answer(cx, 403, "role"); return; }
    F();
}

fn route<F>(cx: Cx&) {
    let f = run() { F() };
    if f.status != 0 {
        cx.status = f.status;
        cx.body.clear();
        format(cx.body, "{\"error\":\"", f.code, "\"}");
    }
}

fn run<F>() -> Failure {
    F();
    return Failure { status: 0, code: [] };
}

fn fail(status: i32, code: const u8[:]) {
    return Failure { status: status, code: code } from run;
}
