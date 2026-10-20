# 08: Small helpers

Status: partial. SSE and cookies out built (2026-10-20); the other parts remain open.

Each is a few lines over what goose-rest and goose-http have. Aegon's pages for them:
`sse`, `static-files`, `response`, and `cors`.

- **SSE.** `event`, `data` (split on newlines), JSON data from a struct's writer,
  `comment` for heartbeats, and `retry`, over `rest::begin` and `rest::pause`. The
  stream sets `Content-Type: text/event-stream`, `Cache-Control: no-cache`, and
  `X-Accel-Buffering: no`, so nginx doesn't buffer it.
- **A directory of files.** `rest::files(cx, prefix, dir)` mounts a directory:
  - an index file, and a MIME type by extension from one table, Aegon's list included
    (`.map`, `.webmanifest`, `.avif`, `.wasm`, and fonts)
  - precompressed copies through goose-http's `http::open_precompressed`
  - only regular files; `..`, `\`, and NUL refused with 404
  - ETag, `Last-Modified`, and ranges, as `rest::file` has them now
- **SPA fallback.** On the directory mount: a missing path without a file extension,
  for a request that accepts HTML, serves `index.html` with 200. A missing asset still
  answers 404, so a browser never runs HTML as a script.
- **`Cache-Control` per file.** A hook given the path and whether it's the fallback,
  for hashed bundles cached for a year and `index.html` with `no-cache`.
- **Cookies out.** `rest::set_cookie` and `rest::clear_cookie` over goose-http's
  `http::set_cookie`, which already checks names, values, and attributes.
  `Partitioned` (CHIPS) waits for a program that needs it. goose-http's `Cookie`
  doesn't have it; this part makes no goose-http change.
- **CORS:**
  - origin patterns (`https://*.example.com`, `http://localhost:*`), matched on the
    whole scheme and host, so `https://example.com.attacker.com` fails
  - a validator function, for tenants' domains
  - `Access-Control-Allow-Private-Network`
  - exposed headers
  - permissive and strict presets
  - the origin echoed with `Vary: Origin` whenever credentials are allowed

## Built (2026-10-20)

`sse.goose` adds `sse_begin`, `sse_event`, `sse_data`, `sse_json`, `sse_comment`, and
`sse_retry` over `begin`, `send`, and `pause`. Frames split LF, CRLF, and bare CR,
preserving empty lines. JSON goes through the struct's `format` writer. Tests in
`test/sse/` cover the bytes, headers, a paused heartbeat followed by an event, HEAD,
and a client that leaves during a pause.

`cookies.goose` adds `set_cookie` and `clear_cookie` over `http::set_cookie`, while
the response head is open. Clearing empties the value and sets `Max-Age=0` and an
expiry at the Unix epoch, retaining the path, domain, and other attributes.
`test/cookies/` checks both response-writing forms, multiple cookies, clearing, and
goose-http's rejection of invalid names, values, and attributes.

Both modules are imported by `rest.goose`. Neither adds fields to `Cx` or other
shared structs, or code to the common request path. The directory mount, SPA fallback,
file caching hook, and CORS remain unchanged.

## Acceptance criteria

- [x] SSE helpers with newline splitting, a heartbeat, a JSON event, and tests
- [x] Cookies out and clearing with tests, using goose-http's validation
- [x] Neither part adds state or work to requests that don't use it
- [ ] Directory mount with tests
- [ ] SPA fallback with tests
- [ ] `Cache-Control` per-file hook with tests
- [ ] CORS additions with tests
- [ ] Each helper with a test, or cancelled here with its reason
- [x] `docs/reference.md` updated for each one added
