# 9. Testing without sockets

`rest::serve_one(text, app) { cx => ... }` takes the bytes of one request, answers it
through the block as `rest::serve` would, and returns the response bytes. The test needs
no sockets, threads, or goose-http types. It runs in-process through TinyCC with
`goose test.goose`. From [`05-schema/test.goose`](05-schema/test.goose):

```rust
    fn answer(text: const u8[:]) -> u8[>..] {
        return rest::serve_one(text, state) { cx => api::dispatch(cx) };
    }
    let auth = "Authorization: Bearer secret\r\n";
    expect(body_of(answer(post("", "{\"name\": \"goose\"}"))), "{\"error\":\"unauthenticated\"}");
    expect(body_of(answer(post(auth, "{\"name\": \"goose\"}"))), "{\"id\":1,\"name\":\"goose\",\"owner\":\"ada\"}");
```

The answer is the complete response, so a test can compare the status line and headers
too. It has no `Date` or `Server` header. `serve_one` behaves like the server:

- The block runs inside `rest::route`, so it can call `rest::fail`.
- A body that doesn't fit alongside its head in the 8 KB read buffer arrives in pieces.
  `rest::body` gathers it, then the block runs again with the whole body. A test with
  a large body therefore covers the rule from [Large bodies](10-large-bodies.md): code
  before a route's first `rest::body` runs twice.
- goose-http's limits apply. A rejected request, such as one with a body exceeding
  `max_body`, gets goose-http's rejection response. A block that writes no answer gets
  500. The full call is `rest::serve_one(text, app, fresh, cfg)`: `app` is the worker
  state, `fresh` is the per-request state, and the optional `cfg` changes the limits.
  Omit `fresh` when there is no per-request state, or both state arguments when neither
  kind of state is needed.
- An HTTP/1.1 request without `Host` is given `Host: localhost`, so a test request can
  leave it out.

```rust
    // A body past the 8 KB read buffer, gathered as the server gathers it, and
    // one past the route's 16 KB x-body-limit.
    expect(body_of(answer(post(auth, padded(10000)))), "{\"id\":2,\"name\":\"swan\",\"owner\":\"ada\"}");
    expect(body_of(answer(post(auth, padded(20000)))), "{\"error\":\"payload_too_large\"}");
```

The test imports `api_gen.goose` and `app.goose`, just as `main.goose` does, so it can't
import `main.goose` itself. Keep the handlers outside the file containing `main`.
[`test/test_router.goose`](../../test/test_router.goose) uses the same approach to compare
the generated router with an `if` chain of the same 60 routes.
[`test/test_serve_one.goose`](../../test/test_serve_one.goose) counts how many times a
route runs for a large body.

## The whole server

To test the whole server, the tutorial programs and examples follow the same pattern.
Each `requests.sh` lists requests as `req METHOD PATH [curl options]`.
`scripts/test-examples.sh` builds the program, starts it on a local port, runs the
requests with `curl`, and compares the `METHOD PATH STATUS BODY` lines with `expected.txt`.
From `05-schema/requests.sh`:

```sh
req POST /v1/projects -H "$auth" -H "$json" -d '{"name": "goose"}'
req GET '/v1/projects?limit=0'
```

```text
POST /v1/projects 201 {"id":1,"name":"goose","owner":"ada"}
GET /v1/projects?limit=0 400 {"error":"invalid_parameter","detail":"limit: minimum"}
```

Pass the directories to test as arguments; `scripts/test-examples.sh docs/tutorial/05-schema`
tests just that example.

---

[Index](README.md) · Previous: [8. State](08-state.md) · Next:
[10. Large bodies](10-large-bodies.md)
