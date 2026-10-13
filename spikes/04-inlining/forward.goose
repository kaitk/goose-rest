import std;

struct Cx { status: i32 }

fn mw<F>(cx: Cx&) {
    guard cx.status == 0 else { return; }
    F();
}

fn route<F>(cx: Cx&) { let r = run(F); cx.status = r; }

fn run<F>() -> i32 { F(); return 0; }

fn handler(cx: Cx&, id: i64) {
    mw(cx) { route(cx) { if id == 3 { cx.status = 1; } }; };
}

fn main() {
    var cx = Cx { status: 0 };
    handler(cx, 3);
    handler(cx, 4);
    print(cx.status);
}
