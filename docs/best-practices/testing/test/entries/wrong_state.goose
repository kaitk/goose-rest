// error: struct NoState has no field use
// The routes served with request state of another type than St: a route that
// asks a lane keeps the lane's mark in the state's use, so the program
// doesn't compile.
import std;
import http from "github.com/kaitk/goose-http@ebb4238728179e82140550af50e5bab1a7e0dab2";
import plod from "../../../../../";
import app from "../../";

fn main() {
    var projects: projects::Project[>..] = [];
    var a = App { projects: projects, writer: plod::Lane<Writes, Use> { lane: http::Lane { .. }, mark: Use.Write } };
    let out = plod::serve_one("POST /entries HTTP/1.1\r\n\r\n", a, plod::NoState { .. }) { cx =>
        if plod::resumed(cx) { plod::on_reply(cx) { resume(cx.state.use, cx); }; } else { handle(cx); }
    };
    print(out);
}
