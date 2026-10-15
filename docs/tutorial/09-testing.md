# 9. Testing without sockets

`rest::serve_one(text, app) { cx => ... }` answers one request, given as its bytes, as
`rest::serve` would through the block, and returns the response's bytes: no socket, no
threads, and no goose-http types in the test. Such a test runs in-process through
TinyCC, `goose test.goose`. From [`05-schema/test.goose`](05-schema/test.goose):

```rust
    fn answer(text: const u8[:]) -> u8[>..] {
        return rest::serve_one(text, state) { cx => api::dispatch(cx) };
    }
    let auth = "Authorization: Bearer secret\r\n";
    expect(body_of(answer(post("", "{\"name\": \"goose\"}"))), "{\"error\":\"unauthenticated\"}");
    expect(body_of(answer(post(auth, "{\"name\": \"goose\"}"))), "{\"id\":1,\"name\":\"goose\",\"owner\":\"ada\"}");
```

The answer is the whole response, so a test can compare the status line and fields too;
it has no `Date` or `Server` field. `serve_one` works as the server does:

- The block runs inside `rest::route`, so it can call `rest::fail`.
- A body that doesn't fit in the 8 KB read buffer with its head arrives in pieces, which
  `rest::body` gathers, and the block runs again with it whole. A test with a long
  body therefore covers the rule from [Large bodies](10-large-bodies.md) that code
  before a route's first `rest::body` runs twice.
- goose-http's limits apply: a request it refuses, such as a body past `max_body`, gets
  its refusal, and a block that writes no answer gets 500. The full call is
  `rest::serve_one(text, app, fresh, cfg)`: `app` is the worker's state, `fresh` the
  per-request state, and the optional `cfg` changes the limits. Leave off `fresh`
  when there is no per-request state, or both state arguments when there is none.
- An HTTP/1.1 request without `Host` is given `Host: localhost`, so a test request can
  leave it out.

```rust
    // A body past the 8 KB read buffer, gathered as the server gathers it, and
    // one past the route's 16 KB x-body-limit.
    expect(body_of(answer(post(auth, padded(10000)))), "{\"id\":2,\"name\":\"swan\",\"owner\":\"ada\"}");
    expect(body_of(answer(post(auth, padded(20000)))), "{\"error\":\"payload_too_large\"}");
```

The test imports `api_gen.goose` and `app.goose` as `main.goose` does, so it can't import
`main.goose` itself: keep the handlers out of the file with `main`.
[`test/test_router.goose`](../../test/test_router.goose) checks the generated router
against an `if` chain of the same 60 routes the same way, and
[`test/test_serve_one.goose`](../../test/test_serve_one.goose) counts a route's runs for
a long body.

## The whole server

For the whole server, the tutorial's programs and the examples follow one pattern: a
`requests.sh` lists requests as `req METHOD PATH [curl options]`, and
`scripts/test-examples.sh` builds the program, starts it on a local port, runs the
requests with `curl`, and compares `METHOD PATH STATUS BODY` lines with `expected.txt`.
From `05-schema/requests.sh`:

```sh
req POST /v1/projects -H "$auth" -H "$json" -d '{"name": "goose"}'
req GET '/v1/projects?limit=0'
```

```text
POST /v1/projects 201 {"id":1,"name":"goose","owner":"ada"}
GET /v1/projects?limit=0 400 {"error":"invalid_parameter","detail":"limit: minimum"}
```

The script takes the directories to test, so `scripts/test-examples.sh docs/tutorial/05-schema`
runs one.

---

[Index](README.md) · Previous: [8. State](08-state.md) · Next:
[10. Large bodies](10-large-bodies.md)
