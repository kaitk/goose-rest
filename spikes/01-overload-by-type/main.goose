import std;

struct Cx { cookie: const u8[:], page: i64, status: i32 }
struct Session { user: i64 }
struct Page { n: i64, size: i64 }

fn from_request(cx: Cx&, v: Session&) { v.user = if cx.cookie == "ok" { 7 } else { 0 }; }
fn from_request(cx: Cx&, v: Page&) { v.n = cx.page; v.size = 20; }

fn take<T, F>(cx: Cx&) {
    var v = default<T>();
    from_request(cx, v);
    F(v);
}

fn main() {
    var cx = Cx { cookie: "ok", page: 3, status: 0 };
    take<Session>(cx) { s => print("session ", s.user); };
    take<Page>(cx) { p => print("page ", p.n, " size ", p.size); };
    take<Session>(cx) { s =>
        take<Page>(cx) { p => print("both ", s.user, " ", p.n); };
    };
}
