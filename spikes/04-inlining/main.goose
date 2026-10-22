import std;
import plod;

fn find(id: i64) -> i64 {
    guard id != 0 else { plod::fail(404, "not_found"); }
    return id * 10;
}

fn handler(cx: plod::Cx&, id: i64) {
    plod::with_cors(cx) {
        plod::with_auth(cx) { s =>
            plod::with_role(cx, s) {
                plod::route(cx) {
                    let v = find(id);
                    cx.status = 200;
                    format(cx.body, "{\"v\":", v, ",\"user\":", s.user, "}");
                };
            };
        };
    };
}

fn main() {
    let cookies = ["ok", "bad", "ok", "ok"];
    let origins = ["", "", "https://evil.example", ""];
    let ids = [5, 5, 5, 0];
    for i in 4 {
        var cx = plod::Cx { cookie: cookies[i], origin: origins[i], status: 0, body: [] };
        handler(cx, ids[i]);
        if i == 0 { handler(cx, 6); }
        print(cx.status, " ", cx.body);
    }
}
