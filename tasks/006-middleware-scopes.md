# 006: Middleware, scopes, and examples

Status: todo

The middleware every API needs, as blocks, and prefix scopes over `http::router`.

## Acceptance criteria

- [ ] CORS, answering a preflight itself; a bearer token check; request timing with
      `Server-Timing` and the access log
- [ ] Prefix scopes, with 404, 405 with `Allow`, and `OPTIONS` from `http::otherwise`
      across them
- [ ] `examples/` with a JSON API without a schema and one with a schema, which
      `scripts/test.sh` builds and requests once per route
- [ ] The README's quick start and API section match the examples
