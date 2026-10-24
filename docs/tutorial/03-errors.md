# 3. Answers and errors

Every route ends in an answer: a value as JSON, text, no body, or an error that a
client can read the same way whichever route wrote it. A route answers once, using one
of these calls:

| Call | Answers |
|---|---|
| `plod::json(cx, status, v)` | `v` as JSON, written by `v`'s `format` overload |
| `plod::json_bytes(cx, status, body)` | JSON the program wrote itself |
| `plod::text(cx, status, s)` | `s` as `text/plain; charset=utf-8` |
| `plod::empty(cx, status)` | no body; 204 and 304 have no `Content-Length`, other statuses have `Content-Length: 0` |
| `plod::bytes(cx, status, content_type, body)` | `body` as it is, under `content_type`, such as a page |
| `plod::fail(cx, status, code)` | `{"error": code}`, from anywhere inside a route |

Each answer but `fail` also takes a block, which adds fields of the route's own with
`plod::field`, such as a `Location`:
`plod::json(cx, 201, p) { plod::field(cx, "Location", str("/projects/", p.id)); };`.

## A value as JSON

`plod::json` calls `format(out, v)`, Goose's one type-directed hook, and Goose finds the
overload in the namespace that declares `v`'s type. A type's JSON comes from a `format`
overload: one you write, one that calls `plod::format_fields`, or the generator's ([JSON bodies](04-json.md)).
From [`02-routes`](02-routes/main.goose):

```rust
fn format(out: u8[>..]&, p: const Project&) {
    out.append("{\"id\":");
    format(out, p.id);
    out.append(",\"name\":");
    http::json_string(out, p.name);
    out.push('}');
}
```

`http::json_string` writes a string as JSON: quoted, with the bytes JSON requires
escaped. It checks 16 bytes at a time for a byte to escape, so write strings with it
rather than with `json::format_string`, whose output is the same.

A writer whose keys are its struct's fields, in order, can be one call.
`plod::format_fields` writes each field under its declared name, from the struct's
declaration. From [`10-large-bodies`](10-large-bodies/main.goose):

```rust
struct Imported { project: i64, imported: i64 }

fn format(out: u8[>..]&, i: const Imported&) { plod::format_fields(out, i); }
```

It writes every field, so a writer that leaves one out keeps its own code, as
`02-routes`' does for `archived`. So does one that renames a key or writes an optional
string. The [reference](../reference.md#11-json-from-a-structs-fields) lists what each field
type becomes.

A type without its own `format` still compiles, but is written in Goose's default
format, such as `app::Session { 1, 2 }`, which isn't JSON. Strings use the standard
library's `format`, which writes their bytes without quotes, so wrap a string answer
in an object.

## Errors

`plod::fail` takes a code, and any function inside a route can call it.
`find_project` returns a reference, and fails when there's no such project:

```rust
fn find_project(cx, id: i64) -> const Project& {
    for &p in PROJECTS {
        if p.id == id { return p; }
    }
    plod::fail(cx, 404, "project_not_found");
}
```

Every error Plod writes, the framework's or the program's, has the same
shape: `{"error": code}`, with `detail` for parameter or body errors and `at` for
the position where the body reader stopped. The [reference](../reference.md#5-errors)
lists each status and code. The first answer wins: a route that answers and then
fails keeps its answer.

A program changes the error shape by overloading `plod::error_body` for its request
state's type, set by `plod::serve(cfg, app, fresh)` ([State](08-state.md)).
The overload handles every error, including the 404s, 405s, and 413s that Plod
itself writes. From [`03-errors`](03-errors/main.goose), which has no worker state:

```rust
struct St { unused: bool = false }

fn plod::error_body(body: u8[>..]&, st: const St&, status: i32, code: const u8[:],
                    detail: const u8[:], at: i64) {
    body.append("{\"error\":{\"code\":");
    http::json_string(body, code);
    body.append(",\"status\":");
    format(body, status);
    if detail.len > 0 {
        body.append(",\"message\":");
        http::json_string(body, detail);
    }
    body.append("}}");
}
```

```rust
    var none = plod::NoState { .. };
    let e = plod::serve(cfg, none, St { .. }) { cx => handle(cx) };
```

```text
GET /projects/2  404 {"error":{"code":"project_not_found","status":404}}
GET /projects/x  400 {"error":{"code":"invalid_parameter","status":400,"message":"id: integer"}}
POST /projects/1 405 {"error":{"code":"method_not_allowed","status":405}}
```

The overload is declared in the `plod` namespace, `fn plod::error_body`, because a
generic function finds names where it's defined, not where it's called. The same holds
for `plod::from_request`, on the next page.

*Note: once an application has several domains, the best practices keep one error
shape and each domain's codes in one place
([Errors](../best-practices/errors.md#42-each-domains-codes-in-one-place)).*

---

[Index](README.md) · Previous: [2. Routes, path, query, and headers](02-routes.md) ·
Next: [4. JSON bodies](04-json.md)
