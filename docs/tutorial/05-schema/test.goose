// docs/tutorial/09-testing.md: the API's routes, answered without a socket.
// scripts/test.sh runs it through TinyCC:
//
//   goose docs/tutorial/05-schema/test.goose
import std;
import http from "github.com/kaitk/goose-http@v0.5.1";
import rest from "../../../";
import .api_gen;
import .app;

fn body_of(out: const u8[:]) -> const u8[:] { out[find(out, "\r\n\r\n") + 4..] }

fn expect(got: const u8[:], want: const u8[:]) {
    if got != want { print("got:  ", got, "\nwant: ", want); assert(false); }
}

fn get(target: const u8[:]) -> u8[>..] { str("GET ", target, " HTTP/1.1\r\n\r\n") }

fn post(fields: const u8[:], body: const u8[:]) -> u8[>..] {
    str("POST /v1/projects HTTP/1.1\r\nContent-Type: application/json\r\n", fields,
        "Content-Length: ", body.len, "\r\n\r\n", body)
}

// A project named swan, with n spaces before the closing brace.
fn padded(n: i64) -> u8[>..] {
    var body: u8[>..] = [];
    body.append("{\"name\": \"swan\"");
    for i in n { body.push(' '); }
    body.push('}');
    return body;
}

fn main() {
    var projects: api::Project[>..] = [];
    var state = app::App { projects: projects, token: "secret" };
    fn answer(text: const u8[:]) -> u8[>..] {
        return rest::serve_one(text, state) { cx => api::dispatch(cx) };
    }
    let auth = "Authorization: Bearer secret\r\n";
    expect(body_of(answer(post("", "{\"name\": \"goose\"}"))), "{\"error\":\"unauthenticated\"}");
    expect(body_of(answer(post(auth, "{\"name\": \"goose\"}"))), "{\"id\":1,\"name\":\"goose\",\"owner\":\"ada\"}");
    expect(answer(get("/v1/projects/1")),
           str("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: 37\r\n\r\n",
               "{\"id\":1,\"name\":\"goose\",\"owner\":\"ada\"}"));
    expect(body_of(answer(get("/v1/projects?limit=0"))),
           "{\"error\":\"invalid_parameter\",\"detail\":\"limit: minimum\"}");
    expect(body_of(answer(get("/v1/projects/2"))), "{\"error\":\"project_not_found\"}");
    // A body past the 8 KB read buffer, gathered as the server gathers it, and
    // one past the route's 16 KB x-body-limit.
    expect(body_of(answer(post(auth, padded(10000)))), "{\"id\":2,\"name\":\"swan\",\"owner\":\"ada\"}");
    expect(body_of(answer(post(auth, padded(20000)))), "{\"error\":\"payload_too_large\"}");
    print("05-schema: ok");
}
