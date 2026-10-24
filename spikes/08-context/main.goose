// Spike 08: hand-written routes whose functions take only cx, with the
// worker's state and the router in it. README.md has the verdict.
import std;
import http from "github.com/kaitk/goose-http@999757063408a9a50c7a865dcad309a213489e33";
import .plod;

struct App { name: const u8[:], projects: i64 }
struct St { seen: i64 = 0 }

// A program's own name for its context, for a function that types it.
type Cx = plod::Cx<St, App>;

fn handle(cx) {
    plod::routes(cx) { cx =>
        cx.state.seen++;
        if plod::on(cx, "GET", "/health") {
            plod::text(cx, 200, "ok");
        } else if plod::scope(cx, "/v1") {
            v1(cx);
        } else {
            plod::otherwise(cx);
        }
    };
}

fn v1(cx) {
    if plod::on(cx, "GET", "/projects/:id") {
        project(cx, plod::param(cx, "id"));
    } else if plod::on(cx, "DELETE", "/projects/:id") {
        typed(cx);
    } else {
        plod::otherwise(cx);
    }
}

fn project(cx, id: const u8[:]) {
    plod::text(cx, 200, str(cx.app.name, " has ", cx.app.projects, " projects; this is ", id));
}

fn typed(cx: const Cx&) {
    plod::text(cx, 204, str("deleted ", plod::param(cx, "id"), " of ", cx.app.name));
}

fn main() {
    var app = App { name: "goose", projects: 3 };
    var st = St { .. };
    for text in ["GET /health HTTP/1.1\r\nHost: x\r\n\r\n",
                 "GET /v1/projects/42 HTTP/1.1\r\nHost: x\r\n\r\n",
                 "DELETE /v1/projects/7 HTTP/1.1\r\nHost: x\r\n\r\n",
                 "POST /v1/projects/7 HTTP/1.1\r\nHost: x\r\n\r\n",
                 "GET /v2 HTTP/1.1\r\nHost: x\r\n\r\n"] {
        let req, status = http::parse(text);
        var out: u8[>..] = [];
        var cx = plod::Cx<St, App> { req: req, out: out, state: st, app: app };
        handle(cx);
        print(out);
    }
    print("requests seen: ", st.seen);
}
