# 3. Answers and errors

A route answers once, with one of these:

| Call | Answers |
|---|---|
| `rest::json(cx, status, v)` | `v` as JSON, written by `v`'s `format` overload |
| `rest::json_bytes(cx, status, body)` | JSON the program wrote itself |
| `rest::text(cx, status, s)` | `s` as `text/plain; charset=utf-8` |
| `rest::empty(cx, status)` | no body; 204 and 304 have no `Content-Length`, other statuses have `Content-Length: 0` |
| `rest::fail(cx, status, code)` | `{"error": code}`, from anywhere inside `rest::route` |
| `http::start`, `http::field`, `http::finish` | anything else, such as a page |

`rest::json` calls `format(out, v)`, Goose's one type-directed hook, and Goose finds the
overload in the namespace that declares `v`'s type. There is no derive: a type gets its
JSON from a `format` you write, or from the generator ([JSON bodies](04-json.md)).
From [`02-routes`](02-routes/main.goose):

```rust
fn format(out: u8[>..]&, p: const Project&) {
    out.append("{\"id\":");
    format(out, p.id);
    out.append(",\"name\":");
    json::format_string(out, p.name);
    out.push('}');
}
```

A type without its own `format` still compiles, and is written as Goose prints it, such
as `app::Session { 1, 2 }`, which isn't JSON. A string's `format` is std's, which writes its
bytes unquoted, so answer a string inside an object.

## Errors

`rest::fail` takes a code, and any function inside a route can call it.
`find_project` returns a reference, and fails where there is nothing to return:

```rust
fn find_project(cx, id: i64) -> const Project& {
    for &p in PROJECTS {
        if p.id == id { return p; }
    }
    rest::fail(cx, 404, "project_not_found");
}
```

Every error goose-rest writes, its own and the program's, has one shape:
`{"error": code}`, with `detail` for a parameter or a body and `at` for where a body's
reader stopped. The [reference](../reference.md#errors) lists each status and code. The
first answer wins: a route that answers and then fails keeps its answer.

A program picks its own shape with an overload of `rest::error_body` for the type of its
per-request state, which `rest::serve(cfg, app, fresh)` sets ([State](08-state.md)).
The overload gets every error, including the 404s, 405s, and 413s goose-rest writes
itself. From [`03-errors`](03-errors/main.goose), which keeps no worker's state:

```rust
struct St { unused: bool = false }

fn rest::error_body(body: u8[>..]&, st: const St&, status: i32, code: const u8[:],
                    detail: const u8[:], at: i64) {
    body.append("{\"error\":{\"code\":");
    json::format_string(body, code);
    body.append(",\"status\":");
    format(body, status);
    if detail.len > 0 {
        body.append(",\"message\":");
        json::format_string(body, detail);
    }
    body.append("}}");
}
```

```rust
    var none = rest::NoState { .. };
    let e = rest::serve(cfg, none, St { .. }) { cx => handle(cx) };
```

```text
GET /projects/2  404 {"error":{"code":"project_not_found","status":404}}
GET /projects/x  400 {"error":{"code":"invalid_parameter","status":400,"message":"id: integer"}}
POST /projects/1 405 {"error":{"code":"method_not_allowed","status":405}}
```

The overload is declared in the `rest` namespace, `fn rest::error_body`, because a
generic function finds names where it's defined, not where it's called. The same holds
for `rest::from_request`, on the next page.

---

[Index](README.md) · Previous: [2. Routes, path, query, and headers](02-routes.md) ·
Next: [4. JSON bodies](04-json.md)
