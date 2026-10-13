import std;

struct Cx { cookie: const u8[:], origin: const u8[:], status: i32, body: u8[..64] }
struct Session { user: i64 }

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
    guard cx.cookie == "ok" else {
        answer(cx, 401, "unauthenticated");
        return;
    }
    F(Session { user: 7 });
}

fn with_role<F>(cx: Cx&, s: Session) {
    guard s.user == 7 else { answer(cx, 403, "role"); return; }
    F();
}

var trace: u8[>..] = [];

fn handler(cx: Cx&, id: i64) -> i64 {
    trace.append("[handler");
    with_cors(cx) {
        with_auth(cx) { s =>
            with_role(cx, s) {
                trace.append(" body");
                if id == 0 {
                    answer(cx, 404, "no id");
                    return -1;
                }
                answer(cx, 200, "ok");
            };
            trace.append(" after-role");
        };
        trace.append(" after-auth");
    };
    trace.append(" end]");
    return id;
}

fn run(cookie: const u8[:], origin: const u8[:], id: i64) {
    var cx = Cx { cookie: cookie, origin: origin, status: 0, body: [] };
    trace.clear();
    let r = handler(cx, id);
    print(cx.status, " ", cx.body, " returned ", r, " trace", trace);
}

fn main() {
    run("ok", "", 5);
    run("bad", "", 5);
    run("ok", "https://evil.example", 5);
    run("ok", "", 0);
}
