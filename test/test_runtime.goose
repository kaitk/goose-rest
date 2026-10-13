// The runtime's answers, byte for byte: rest::text and rest::json, a
// failure from any depth below rest::route, a body a generated reader
// refused, and rest::otherwise's 404, 405, and the rest.
// scripts/test-unit.sh runs this through TinyCC.
import std;
import json;
import http from "github.com/kaitk/goose-http@e27ab215c8101a231a375cdfada182d3c9b388d7";
import rest from "../";
import .gen.api_gen;

struct Project { id: i64, name: const u8[:] }

fn format(out: u8[>..]&, p: const Project&) {
    out.append("{\"id\":");
    format(out, p.id);
    out.append(",\"name\":");
    json::format_string(out, p.name);
    out.push('}');
}

fn same(got: const u8[:], want: const u8[:]) {
    if got != want {
        print("got:\n", got, "\nwant:\n", want);
        assert(false);
    }
}

// Calls H with a context for text, a whole request, and compares what it
// wrote with want and then more.
fn answers<H>(text: const u8[:], want: const u8[:], more: const u8[:] = "") {
    let req, status = http::parse(text);
    assert(status == 200);
    var out: u8[>..] = [];
    var keep = true;
    var st = http::Stream { .. };
    var state = rest::NoState { .. };
    let body = text[req.len..];
    var scratch: u8[>..] = [];
    var cx = rest::Cx<rest::NoState> { req: req, body: body, out: http::Reply { buf: out, common: "", keep_alive: keep,
                        minor: 1, head: false, stream: st }, state: state, scratch: scratch };
    H(cx);
    same(out, str(want, more));
}

fn find(cx, id: i64) -> Project {
    guard id != 0 else { rest::fail(cx, 404, "project_not_found"); }
    return Project { id: id, name: "goose \"one\"" };
}

fn load(cx, id: i64) -> Project {
    let p = find(cx, id);
    guard p.id != 13 else { rest::fail(cx, 403, str("forbidden_", p.id)); }
    return p;
}

let GET = "GET /p HTTP/1.1\r\nHost: x\r\n\r\n";

fn test_text_and_json() {
    answers(GET, "HTTP/1.1 200 OK\r\nContent-Type: text/plain; charset=utf-8\r\nContent-Length: 2\r\n\r\nok") { cx =>
        rest::text(cx, 200, "ok");
    };
    answers(GET, "HTTP/1.1 201 Created\r\nContent-Type: application/json\r\nContent-Length: 31\r\n\r\n",
                 "{\"id\":7,\"name\":\"goose \\\"one\\\"\"}") { cx =>
        rest::json(cx, 201, Project { id: 7, name: "goose \"one\"" });
    };
}

fn test_route() {
    answers(GET, "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: 31\r\n\r\n",
                 "{\"id\":7,\"name\":\"goose \\\"one\\\"\"}") { cx =>
        rest::route(cx) { rest::json(cx, 200, load(cx, 7)); };
    };
    // Two calls down, and with text owned by the failure.
    answers(GET, "HTTP/1.1 404 Not Found\r\nContent-Type: application/json\r\nContent-Length: 29\r\n\r\n",
                 "{\"error\":\"project_not_found\"}") { cx =>
        rest::route(cx) { rest::json(cx, 200, load(cx, 0)); };
    };
    answers(GET, "HTTP/1.1 403 Forbidden\r\nContent-Type: application/json\r\nContent-Length: 24\r\n\r\n",
                 "{\"error\":\"forbidden_13\"}") { cx =>
        rest::route(cx) { rest::json(cx, 200, load(cx, 13)); };
    };
    answers(GET, "HTTP/1.1 409 Conflict\r\nContent-Type: application/json\r\nContent-Length: 17\r\n\r\n",
                 "{\"error\":\"taken\"}") { cx =>
        rest::route(cx) { rest::fail(cx, 409, "taken"); };
    };
    // The first answer wins: a failure after one leaves it as it is.
    answers(GET, "HTTP/1.1 200 OK\r\nContent-Type: text/plain; charset=utf-8\r\nContent-Length: 5\r\n\r\n",
                 "first") { cx =>
        rest::route(cx) {
            rest::text(cx, 200, "first");
            rest::fail(cx, 409, "taken");
        };
    };
}

fn test_fail_body() {
    let post = "POST /p HTTP/1.1\r\nHost: x\r\nContent-Length: 17\r\n\r\n{\"name\": \"goose\"}";
    answers(post, "HTTP/1.1 400 Bad Request\r\nContent-Type: application/json\r\nContent-Length: 56\r\n\r\n",
                  "{\"error\":\"invalid_body\",\"detail\":\"id: required\",\"at\":17}") { cx =>
        rest::route(cx) {
            var r = json::reader(cx.body);
            var scratch: u8[>..] = [];
            let p = api::read_project(r, scratch);
            if !json::finish(r) { rest::fail_body(cx, r); }
            rest::json(cx, 200, p);
        };
    };
}

fn test_otherwise() {
    answers(GET, "HTTP/1.1 404 Not Found\r\nContent-Type: application/json\r\nContent-Length: 21\r\n\r\n",
                 "{\"error\":\"not_found\"}") { cx =>
        var r = http::router(cx.req);
        if http::on(r, "GET", "/q") { rest::text(cx, 200, "q"); } else { rest::otherwise(cx, r); }
    };
    answers(GET, "HTTP/1.1 405 Method Not Allowed\r\nAllow: POST, PUT\r\nContent-Type: application/json\r\n",
                 "Content-Length: 30\r\n\r\n{\"error\":\"method_not_allowed\"}") { cx =>
        var r = http::router(cx.req);
        if http::on(r, "POST", "/p") { rest::text(cx, 200, "p"); }
        else if http::on(r, "PUT", "/p") { rest::text(cx, 200, "p"); }
        else { rest::otherwise(cx, r); }
    };
    answers("OPTIONS /p HTTP/1.1\r\nHost: x\r\n\r\n", "HTTP/1.1 204 No Content\r\nAllow: GET, HEAD\r\n\r\n") { cx =>
        var r = http::router(cx.req);
        if http::on(r, "GET", "/p") { rest::text(cx, 200, "p"); } else { rest::otherwise(cx, r); }
    };
    answers("BREW /p HTTP/1.1\r\nHost: x\r\n\r\n",
            "HTTP/1.1 501 Not Implemented\r\nContent-Type: application/json\r\nContent-Length: 27\r\n\r\n",
            "{\"error\":\"not_implemented\"}") { cx =>
        var r = http::router(cx.req);
        if http::on(r, "GET", "/p") { rest::text(cx, 200, "p"); } else { rest::otherwise(cx, r); }
    };
    answers("GET /a/../p HTTP/1.1\r\nHost: x\r\n\r\n",
            "HTTP/1.1 400 Bad Request\r\nContent-Type: application/json\r\nContent-Length: 20\r\n\r\n",
            "{\"error\":\"bad_path\"}") { cx =>
        var r = http::router(cx.req);
        if http::on(r, "GET", "/p") { rest::text(cx, 200, "p"); } else { rest::otherwise(cx, r); }
    };
}

fn main() {
    test_text_and_json();
    test_route();
    test_fail_body();
    test_otherwise();
    print("test_runtime: ok");
}
