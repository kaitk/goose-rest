// The projects' routes, through rest::serve_one: the request's bytes in, the
// response's bytes out, with no socket or thread.
import std;
import http from "github.com/kaitk/goose-http@1ebca1fd5561ec8b070b42323fa2bf0ea6622be5";
import rest from "../../../../../";
import app from "../../";
import expect from "../";

fn main() {
    // The worker state main.goose's worker builds, with a box nothing takes
    // from: these routes don't ask the writer.
    let box, e = http::mail_open(2, 256);
    http::exit_on_error(e);
    var projects: projects::Project[>..] = [];
    var a = App { projects: projects, writer: http::address(box, 0) };
    fn answer(text: const u8[:]) -> u8[>..] {
        let out = rest::serve_one(text, a, St { .. }) { cx => handle(cx); };
        return expect::shown(out);
    }

    print("create: ", answer(expect::request("POST", "/projects", "name=goose")));
    print("create with no name: ", answer(expect::request("POST", "/projects", "other=goose")));
    print("create with an empty name: ", answer(expect::request("POST", "/projects", "name=")));
    print("archive: ", answer(expect::request("POST", "/projects/1/archive")));
    print("archive again: ", answer(expect::request("POST", "/projects/1/archive")));
    print("archive another: ", answer(expect::request("POST", "/projects/9/archive")));
}
