# goose-rest, by example

This tutorial builds a projects API with goose-rest, one step per page. It assumes you
know another web framework, such as Actix, Axum, Express, or FastAPI, and have read
[Goose, by example](https://github.com/aardappel/goose/blob/master/docs/tutorial.md)
or will read it alongside this tutorial. It focuses on how goose-rest differs from those
frameworks; the [reference](../reference.md) and the [generator reference](../generator.md)
give the exact rules.

Each page's code is a program in the folder of the same name. `scripts/test.sh` builds
each program, sends it the requests in its `requests.sh`, and compares the answers with
its `expected.txt`. Every Goose and JSON block on a page is quoted from a program, so
what the page shows matches what the code does.

## Part one: the basics

1. [Running something](01-running.md): `rest::serve`, `rest::route`, `rest::fail`
2. [Routes, path, query, and headers](02-routes.md): `rest::on`, `rest::param`, `rest::query`
3. [Answers and errors](03-errors.md): `rest::json`, `rest::fail`, the error shape
4. [JSON bodies](04-json.md): `rest::take`, `rest::json_body`, generated readers
5. [The API from a schema](05-schema.md): `goose-rest gen`, `api::dispatch`, and hand-written routes alongside the generated router
6. [The schema in TypeScript, Python, or Rust](06-schema-languages.md): `api.json` from code
7. [Middleware and scopes](07-middleware.md): `rest::timed`, `rest::cors`, `rest::bearer`, your own
8. [State](08-state.md): `cx.app`, `cx.state`, `rest::once`
9. [Testing without sockets](09-testing.md): `rest::serve_one`

## Part two: waits, bodies, and limits

10. [Large bodies](10-large-bodies.md): `rest::body`, a CSV import gathered whole up to a limit
11. [Work that waits](11-waiting.md): a database behind a lane, an enum of its jobs, `rest::ask`, `run` and `resume`
12. [Two lanes, or a reply in pieces](12-two-lanes.md): `rest::relay`, a case function that asks again
13. [Limits](13-limits.md): 504, 503, a client that has gone, a slow client, a background task the client polls
14. [Bodies read as they arrive](14-bodies-in-pieces.md): `rest::body_in_pieces`, attachments of any size, a multipart form
15. [Long responses and files](15-long-responses.md): `rest::begin`, `rest::send`, an export in pieces, `rest::file`, Server-Sent Events with `rest::pause`
16. [Testing the application](16-testing.md): use cases as plain calls, routes and their case functions given replies, timing over HTTP
17. [Embedded Linux](17-embedded-linux.md): one worker and small limits on a board

## Where to go next

- [Best practices](../best-practices/README.md): how to lay out an application that
  grows, by domain, and what to name each part.
- [Reference](../reference.md): every middleware, extractor, and error code.
- [Generator](../generator.md): what the generator reads, what it writes, what it
  refuses, and how the router matches.
- [`examples/`](../../examples/): complete programs to start from, without a schema
  (`plain`), from one (`schema`), on a board (`device`), and an upgraded connection
  (`upgrade`).
- [Architecture](../architecture.md): the ideas goose-rest takes from Actix and
  Elysia, and how Goose shapes the design.
- [goose-http's patterns](https://github.com/kaitk/goose-http/blob/main/docs/patterns.md):
  how the event loop reads, sends, and waits, which every page of part two builds on.

Clients can be generated from the same `api.json`. Standard OpenAPI tools, such as
[OpenAPI Generator](https://openapi-generator.tech/), generate clients in Python, C,
and most other languages, so the server and its clients share one contract.
