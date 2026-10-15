# 10. Large bodies

The projects get tasks, imported from a spreadsheet as CSV: thousands of lines, past the
8 KB that goose-http reads a request into. goose-rest gathers such a body whole, up to a
limit the route sets, and then calls the route with it. How goose-http reads a body,
and the other ways it can: [goose-http's request bodies](https://github.com/kaitk/goose-http/blob/main/docs/patterns.md#request-bodies).

## Gathered whole, up to a limit

A body that fits the read buffer with its head comes to the handler whole. A longer one
is gathered only when a route asks for it, with `rest::body(cx, limit)`, or with
`rest::take` of a JSON type, which calls `rest::body` with its default of 1 MB. From
[`10-large-bodies`](10-large-bodies/main.goose):

```rust
// The most bytes an import takes: past the 8 KB read buffer, and below the
// server's 1 MB, so the route's limit is the one that applies.
let IMPORT_LIMIT: i64 = 256 * 1024;
```

```rust
// Each record is title,assignee. The whole body is checked before any task
// is added, so a bad record adds none.
fn import_tasks(cx, project: i64) {
    let kind, has_kind = rest::header(cx, "Content-Type");
    guard has_kind && starts_with(kind, "text/csv") else { rest::fail(cx, 415, "unsupported_media_type"); }
    let text = rest::body(cx, IMPORT_LIMIT);
    var good = true;
    let ok = csv::each_record(text) { f =>
        if f.len != 2 || f[0].len < 1 || f[0].len > 128 || f[1].len > 32 { good = false; }
    };
    guard ok && good else { rest::fail(cx, 400, "invalid_csv"); }
    var n = 0;
    csv::each_record(text) { f =>
        cx.app.tasks.push(Task { project: project, title: f[0], assignee: f[1] });
        n++;
    };
    rest::json(cx, 201, Imported { project: project, imported: n });
}
```

```text
POST /v1/projects/1/tasks/import 201 {"project":1,"imported":2}
POST /v1/projects/1/tasks/import 201 {"project":1,"imported":1000}     13 KB, gathered
POST /v1/projects/1/tasks/import 413 {"error":"payload_too_large"}     289 KB
POST /v1/projects/9/tasks/import 404 {"error":"project_not_found"}     not read
POST /v1/projects/1/tasks/import 415 {"error":"unsupported_media_type"}
POST /v1/projects/1/tasks/import 400 {"error":"invalid_csv"}
```

## The code before `rest::body` runs twice

At a route's first `rest::body` or `rest::take`, for a body that hasn't all arrived, the
route leaves without answering. `rest::serve` reads the body up to the limit, then calls
the handler again with the body whole. So the code before that first call runs twice for
a long body, and must not change state.

A check there is fine, and an answer there ends the request without reading the body.
The import's route finds the project and checks the `Content-Type` before `rest::body`,
so an import into a project that doesn't exist gets its 404 before any of its 13 KB is
read:

```rust
        } else if rest::on(cx, "POST", "/v1/projects/:id/tasks/import") {
            rest::route(cx) { import_tasks(cx, project(cx)); };
```

```rust
fn project(cx) -> i64 {
    let id = rest::param_int(cx, "id");
    guard id >= 1 && id <= PROJECTS else { rest::fail(cx, 404, "project_not_found"); }
    return id;
}
```

The tasks are added after `rest::body`, in the run that has the body, so they're added
once.

## Three limits

Three limits apply, and the smallest wins:

| Limit | Set by | Past it |
|---|---|---|
| A route's | its first `rest::body(cx, limit)`, 1 MB without one | 413 `{"error":"payload_too_large"}` |
| A generated route's | `x-body-limit` on its `requestBody`, in bytes | the same |
| The server's | `http::Config`'s `max_body`, 1 MB by default | goose-http's 413, without a body, before any route runs |

The import takes up to 256 KB, under the server's 1 MB, so the program keeps the
default. A route that takes more raises `max_body` to its limit, as
[`05-schema`](05-schema/main.goose) does for its 2 MB uploads:

```rust
    let cfg = http::Config { port: port as i32, workers: 1, max_body: max(api::MAX_BODY, UPLOAD_LIMIT), .. };
```

`api::MAX_BODY` is the largest `x-body-limit` in the schema, or 1 MB.

A body whose `Content-Length` is over the limit is refused before it's sent, and a
chunked one once it passes the limit. The first call's limit holds for the request, so a
route that takes a JSON body over 1 MB calls `rest::body` with its limit before
`rest::take`, as a generated route does for its `x-body-limit`.

The worker holds each body it gathers until the route returns, so a limit is also the
memory each connection importing at once can take. A body too large for that, such as an
attachment of any size, is read in pieces as it arrives, which goose-rest can't do yet
(page 11, to come).

---

[Index](README.md) · Previous: [9. Testing without sockets](09-testing.md) · Next:
[13. Work that waits](13-waiting.md)
