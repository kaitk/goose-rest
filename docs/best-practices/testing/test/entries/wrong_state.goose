// error: struct NoState has no field waiting
// The routes served with request state of another type than St: a route that
// asks a lane keeps its step in the state's Waiting, so the program doesn't
// compile.
import std;
import http from "github.com/kaitk/goose-http@ff18ecc766651a4ff0143361413c81f33873c8b2";
import rest from "../../../../../";
import app from "../../";

fn main() {
    var projects: projects::Project[>..] = [];
    var a = App { projects: projects, writer: http::Lane { .. } };
    let out = rest::serve_one("POST /entries HTTP/1.1\r\n\r\n", a, rest::NoState { .. }) { cx =>
        if rest::resumed(cx) { resume(cx.state.waiting, cx); } else { handle(cx); }
    };
    print(out);
}
