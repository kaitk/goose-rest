// Spike 08: hand-written routes whose functions take only cx, with the
// worker's state and the router in it. README.md has the verdict.
import std;
import http from "github.com/kaitk/goose-http@cbffc2a2b67db1a06467486cb128dda4b28e6eea";
import .rest;

struct App { name: const u8[:], projects: i64 }
struct St { seen: i64 = 0 }

// A program's own name for its context, for a function that types it.
type Cx = rest::Cx<St, App>;

fn handle(cx) {
    rest::routes(cx) { cx =>
        cx.state.seen++;
        if rest::on(cx, "GET", "/health") {
            rest::text(cx, 200, "ok");
        } else if rest::scope(cx, "/v1") {
            v1(cx);
        } else {
            rest::otherwise(cx);
        }
    };
}

fn v1(cx) {
    if rest::on(cx, "GET", "/projects/:id") {
        project(cx, rest::param(cx, "id"));
    } else if rest::on(cx, "DELETE", "/projects/:id") {
        typed(cx);
    } else {
        rest::otherwise(cx);
    }
}

fn project(cx, id: const u8[:]) {
    rest::text(cx, 200, str(cx.app.name, " has ", cx.app.projects, " projects; this is ", id));
}

fn typed(cx: const Cx&) {
    rest::text(cx, 204, str("deleted ", rest::param(cx, "id"), " of ", cx.app.name));
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
        var cx = rest::Cx<St, App> { req: req, out: out, state: st, app: app };
        handle(cx);
        print(out);
    }
    print("requests seen: ", st.seen);
}
