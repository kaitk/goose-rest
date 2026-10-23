// The projects' routes, through plod::serve_one: the request's bytes in, the
// response's bytes out, with no socket or thread.
import std;
import http from "github.com/kaitk/goose-http@v0.5.8";
import plod from "../../../../../";
import app from "../../";
import expect from "../";

fn main() {
    // The worker state main.goose's worker builds, with an empty lane: these
    // routes don't ask the writer.
    var projects: projects::Project[>..] = [];
    var a = App { projects: projects, writer: plod::Lane<Writes, Use> { lane: http::Lane { .. }, mark: Use.Write } };
    fn answer(text: const u8[:]) -> u8[>..] {
        let out = plod::serve_one(text, a, St { .. }) { cx => handle(cx); };
        return expect::shown(out);
    }

    print("create: ", answer(expect::request("POST", "/projects", "name=goose")));
    print("create with no name: ", answer(expect::request("POST", "/projects", "other=goose")));
    print("create with an empty name: ", answer(expect::request("POST", "/projects", "name=")));
    print("archive: ", answer(expect::request("POST", "/projects/1/archive")));
    print("archive again: ", answer(expect::request("POST", "/projects/1/archive")));
    print("archive another: ", answer(expect::request("POST", "/projects/9/archive")));
}
