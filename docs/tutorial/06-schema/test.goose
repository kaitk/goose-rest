// docs/tutorial.md, section 12: the API's routes, answered without a socket.
// scripts/test.sh runs it through TinyCC:
//
//   goose docs/tutorial/06-schema/test.goose
import std;
import http from "github.com/kaitk/goose-http@e27ab215c8101a231a375cdfada182d3c9b388d7";
import rest from "../../../";
import .api_gen;
import .app;

// What dispatch answers to a request, given as its bytes: the status line,
// the fields, and the body.
fn answer(state: app::App&, text: const u8[:]) -> u8[>..] {
    var out: u8[>..] = [];
    let req, status = http::parse(text);
    assert(status == 200);
    var keep = true;
    var stream = http::Stream { .. };
    var none = rest::NoState { .. };
    var scratch: u8[>..] = [];
    var cx = rest::Cx<rest::NoState> {
        req: req, body: text[req.len..],
        out: http::Reply { buf: out, common: "", keep_alive: keep, minor: 1, head: false, stream: stream },
        state: none, scratch: scratch,
    };
    api::dispatch(cx, state);
    return out;
}

fn body_of(out: const u8[:]) -> const u8[:] { out[find(out, "\r\n\r\n") + 4..] }

fn expect(got: const u8[:], want: const u8[:]) {
    if got != want { print("got:  ", got, "\nwant: ", want); assert(false); }
}

fn get(target: const u8[:]) -> u8[>..] { str("GET ", target, " HTTP/1.1\r\nHost: x\r\n\r\n") }

fn post(fields: const u8[:], body: const u8[:]) -> u8[>..] {
    str("POST /v1/projects HTTP/1.1\r\nHost: x\r\nContent-Type: application/json\r\n", fields,
        "Content-Length: ", body.len, "\r\n\r\n", body)
}

fn main() {
    var projects: api::Project[>..] = [];
    var state = app::App { projects: projects, token: "secret" };
    expect(body_of(answer(state, post("", "{\"name\": \"goose\"}"))), "{\"error\":\"unauthenticated\"}");
    expect(body_of(answer(state, post("Authorization: Bearer secret\r\n", "{\"name\": \"goose\"}"))),
           "{\"id\":1,\"name\":\"goose\",\"owner\":\"ada\"}");
    expect(answer(state, get("/v1/projects/1")),
           str("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: 37\r\n\r\n",
               "{\"id\":1,\"name\":\"goose\",\"owner\":\"ada\"}"));
    expect(body_of(answer(state, get("/v1/projects?limit=0"))),
           "{\"error\":\"invalid_parameter\",\"detail\":\"limit: minimum\"}");
    expect(body_of(answer(state, get("/v1/projects/2"))), "{\"error\":\"project_not_found\"}");
    print("06-schema: ok");
}
