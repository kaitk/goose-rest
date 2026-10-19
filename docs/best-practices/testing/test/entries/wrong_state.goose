// error: struct NoState has no field waiting
// The routes served with request state of another type than St: a route that
// asks a lane keeps its step in the state's Waiting, so the program doesn't
// compile.
import std;
import http from "github.com/kaitk/goose-http@81bbf9baa315ad3607cd2a3a67fa7d14d154726c";
import rest from "../../../../../";
import app from "../../";

fn main() {
    let box, e = http::mail_open(2, 256);
    var projects: projects::Project[>..] = [];
    var a = App { projects: projects, writer: http::address(box, 0) };
    let out = rest::serve_one("POST /entries HTTP/1.1\r\n\r\n", a, rest::NoState { .. }) { cx =>
        if rest::resumed(cx) { resume(cx.state.waiting, cx); } else { handle(cx); }
    };
    print(out);
}
