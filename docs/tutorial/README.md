# goose-rest, by example

This tutorial builds a projects API with goose-rest, one step per page. It assumes you
know another web framework, such as Actix, Axum, Express, or FastAPI, and have read
[Goose, by example](https://github.com/aardappel/goose/blob/master/docs/tutorial.md),
or will alongside this. It covers what differs from those frameworks; the
[reference](../reference.md) and the [generator reference](../generator.md) have the
exact rules.

Each page's code is a program in the folder of the same name. `scripts/test.sh` builds
each one, sends it the requests in its `requests.sh`, and compares the answers with its
`expected.txt`, and every Goose and JSON block on a page is quoted from a program, so
what a page shows is what the code does.

## Part one: the basics

1. [Running something](01-running.md): `rest::serve`, `rest::route`, `rest::fail`
2. [Routes, path, query, and headers](02-routes.md): `rest::on`, `rest::param`, `rest::query`
3. [Answers and errors](03-errors.md): `rest::json`, `rest::fail`, the error shape
4. [JSON bodies](04-json.md): `rest::take`, `rest::json_body`, generated readers
5. [The API from a schema](05-schema.md): `goose-rest gen`, `api::dispatch`, hand-written routes beside it
6. [The schema in TypeScript, Python, or Rust](06-schema-languages.md): `api.json` from code
7. [Middleware and scopes](07-middleware.md): `rest::timed`, `rest::cors`, `rest::bearer`, your own
8. [State](08-state.md): `cx.app`, `cx.state`, `rest::once`
9. [Testing without sockets](09-testing.md): `rest::serve_one`

## Part two: bodies, waits, and limits

10. [Large bodies](10-large-bodies.md): `rest::body`, a CSV import gathered whole up to a limit
11. Bodies read as they arrive: TBD, goose-rest can't read a body in pieces yet
12. Long responses and files: TBD, goose-rest can't send a response in pieces yet
13. [Work that waits](13-waiting.md): a database behind a service, `rest::ask`, `rest::answer_value`
14. [Two services, or a reply in pieces](14-two-services.md): `rest::relay`, a case function that asks again
15. [Limits](15-limits.md): 504, 503, a client that has gone, a slow client, a job the client polls
16. [Embedded Linux](16-embedded-linux.md): one worker and small limits on a board

## Where to go next

- [Reference](../reference.md): every middleware, extractor, and error code.
- [Generator](../generator.md): what the generator reads, what it writes, what it
  refuses, and how the router matches.
- [`examples/`](../../examples/): complete programs to start from, without a schema
  (`plain`), from one (`schema`), and on a board (`device`).
- [Architecture](../architecture/README.md): why goose-rest is shaped this way, from
  Actix and Elysia, and where Goose made it differ.
- [goose-http's patterns](https://github.com/kaitk/goose-http/blob/main/docs/patterns.md):
  how the loop reads, sends, and waits, under every page of part two.

Clients come from the same `api.json`: standard OpenAPI tools, such as
[OpenAPI Generator](https://openapi-generator.tech/), write a Python or C client from
it, or one in most other languages, so the contract the server is generated from is
also the client's.
