import std;
import plod;
import app;

fn dispatch(cx: plod::Cx&, id: i64) {
    plod::serve(cx) { app::get_project(cx, id) };
}

fn main() {
    for id in [42, 0, 13, 7] {
        var cx = plod::Cx { path: "/projects", status: 0, body: [] };
        dispatch(cx, id);
        print(id, ": ", cx.status, " ", cx.body);
    }
}
