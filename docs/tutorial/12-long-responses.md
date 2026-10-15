# 12. Long responses and files

A project's tasks can be exported as CSV, and its files downloaded. Either can be larger
than a worker should build whole: the worker holds a response it builds until the client
has taken all of it, and a slow client takes a long time. So these go in pieces, each
made or read when the client has taken the one before. How goose-http sends a response
this way:
[goose-http's long responses](https://github.com/kaitk/goose-http/blob/main/docs/patterns.md#long-responses).

## An export, made as the client takes it

`rest::begin(cx, status, content_type, length, w)` starts the response, with a length of
-1 when it isn't known yet, which sends it chunked. Like `rest::body_in_pieces`
([page 11](11-bodies-in-pieces.md)), it keeps a `Waiting` variant, `w`, in the state.
The route can send the first piece at once with `rest::send`. From
[`12-long-responses`](12-long-responses/main.goose):

```rust
// GET /v1/projects/:id/tasks.csv: the header now, and the rows as the
// client takes them.
fn export_tasks(cx, project: i64) {
    rest::begin(cx, 200, "text/csv; charset=utf-8", -1, Waiting.Export { project: project });
    rest::send(cx, "id,title,assignee\n");
}
```

The handler is then called again, through `rest::resumed` and the case function, with
`cx.kind` `http::MORE` each time the client has taken what was sent. Each call sends the
next 500 rows, about 16 KB, and the last ends the response with `rest::end`:

```rust
fn resume(w: Waiting.Export, cx) {
    guard cx.kind == http::MORE else { return; }   // CLOSED: the state holds nothing to release
    var piece: u8[>..] = [];
    cx.state.next = tasks_csv(piece, cx.app.tasks, w.project, cx.state.next, ROWS_PER_PIECE);
    rest::send(cx, piece);
    if cx.state.next < 0 { rest::end(cx); }
}
```

`tasks_csv` appends up to 500 rows to `piece`, starting at the task `cx.state.next`, and
returns where the next piece starts, or -1 after the last row. So the call that sends the
last rows also ends the response. Where the export has got to goes in the request's
state:

```rust
struct St {
    waiting: Waiting = Waiting.None,
    next: i64 = 0,                                // the export's next task
    file: http::FileBody = http::FileBody { .. }, // what's left of a download
}
```

The worker holds one piece at a time, however many tasks a project has. A client that
reads slowly gets no `MORE` until it has read, so it can't make the worker hold more:

```text
GET /v1/projects/1/tasks.csv 200 transfer-encoding: chunked lines=2001     500 rows at each MORE
GET /v1/projects/2/tasks.csv 200 id,title,assignee ...
GET /v1/projects/9/tasks.csv 404 {"error":"project_not_found"}
GET /v1/projects/1/tasks.csv 200 transfer-encoding: chunked lines=2001     read at 20 KB a second
```

A case function that neither sends nor ends at `MORE` makes goose-http close the
connection. The case function gets `http::CLOSED` once if the response ends otherwise:
when the client goes, or when the route fails with the response begun. Its head has
gone, so the failure can't be answered in the error shape: `rest::route` leaves the
response unended and the connection closes, and the client sees it cut short. The
export holds nothing to release, so it ignores `CLOSED`. A `HEAD` request gets the head
alone, and no calls.

## Files

`rest::file(cx, path, body, w)` answers with a file, as goose-http's `http::serve_file`
does: 200, 206 for a range, 304 when the client's copy is current, or 416 for a range
past the end, with `ETag`, `Last-Modified`, and `Accept-Ranges`. It fails with 404
`file_not_found` when there is no file, and 403 `forbidden` when the program can't read
it. `http::file_path` joins the project's folder and the name from the path, decoded,
and refuses a name that would leave the folder:

```rust
// GET /v1/projects/:id/files/*name: 200, 206 for a range, 304 for a
// matching If-None-Match, 416, and 404 file_not_found.
fn download(cx, project: i64) {
    var path: u8[>..] = [];
    guard http::file_path(str(cx.app.files, "/", project), rest::param(cx, "name"), path) else {
        rest::fail(cx, 400, "bad_path");
    }
    rest::file(cx, path, cx.state.file, Waiting.Download);
}
```

The open file and what's left to send of it are an `http::FileBody`, `body`, kept in the
state, so a program that serves no files keeps none. The case function hands each call
to `rest::send_file`, which sends the next piece of up to 64 KB at each `MORE`, ends
the response after the last, and closes the file at `CLOSED`:

```rust
fn resume(w: Waiting.Download, cx) { rest::send_file(cx, cx.state.file); }
```

```text
GET /v1/projects/1/files/plans.txt 200 content-length: 220000 lines=20000
GET /v1/projects/1/files/plans.txt 206 line 00002            Range: bytes=11-20
GET /v1/projects/1/files/plans.txt 416                       Range: bytes=300000-
GET /v1/projects/1/files/plans.txt 304                       If-None-Match: its ETag
GET /v1/projects/1/files/missing.txt 404 {"error":"file_not_found"}
GET /v1/projects/1/files/a%5Cb 400 {"error":"bad_path"}
```

## Which answer to use

| The route has | Use |
|---|---|
| A value that fits in memory | `rest::json`, `rest::text` ([page 3](03-errors.md)) |
| Data it makes as it goes, such as an export | `rest::begin`, `rest::send` at each `MORE`, `rest::end` |
| A file | `rest::file` and `rest::send_file` |
| A service's reply, in pieces | `rest::relay` ([page 14](14-two-services.md)) |

As at a body's `END` ([page 11](11-bodies-in-pieces.md#answers-written-at-the-end)), a
response begun after the request's first call has no CORS fields and no
`Server-Timing`. One begun in the route, as both here are, has both.

---

[Index](README.md) · Previous: [11. Bodies read as they arrive](11-bodies-in-pieces.md) ·
Next: [13. Work that waits](13-waiting.md)
