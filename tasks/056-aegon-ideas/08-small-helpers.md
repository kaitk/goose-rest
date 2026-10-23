# 08: Small helpers

Status: partial. SSE and cookies out built (2026-10-20), and the directory mount
(2026-10-23); the SPA fallback, the `Cache-Control` hook, and CORS remain open.

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

## Built (2026-10-23)

`plod::files(cx, dir, name, body, u)` in `pieces.goose` serves the directory mount
inside a route that ends in `*name`, such as
`plod::get(cx, "/static/*name") { plod::files(cx, dir, "name", cx.state.file, Use.File); }`,
with `plod::file`'s case function, `plod::send_file`. A call in a route, not a mount
call taking a prefix, since the router already matches the prefix and the program
already chooses the method, guards, and middleware around the route. The mount takes
the parameter's name and reads it still encoded, so `http::file_path` decodes it once.
`plod::file` and `plod::files` share `serve_opened`, which maps the open's status to
the failure and starts the response.

- Paths: `http::file_path`. A refused name answers 404 `file_not_found`; the router
  answers a `.` or `..` segment, escaped or not, with 400 `bad_path` first.
- Index: a name that is empty or ends in `/` gets `index.html` appended. A directory
  named without the `/` answers 404, as no file does: its page's relative links would
  resolve against its parent, and a redirect is more than this needs.
- Precompressed copies: `http::open_precompressed`, which also sets `Content-Encoding`
  and `Vary: Accept-Encoding` through `http::serve_file`. The type is the original's.
- MIME types: goose-http's `http::content_type_of`. It lacks `.map`
  (`application/json`), `.webmanifest` (`application/manifest+json`), and `.otf`
  (`font/otf`), which then go as `application/octet-stream`; adding them is a
  goose-http change. It has `.avif`, `.wasm`, `.woff`, `.woff2`, and `.ttf`.

`test/pieces/files.goose` covers a file with its type, a directory's `index.html`, a
directory without one, a directory named without its `/`, `..`, `%2e%2e`, escaped `/` and `\`, `.gz` and `.br` copies by
`Accept-Encoding` and the plain file without one, HEAD, and a range.

## Acceptance criteria

- [x] SSE helpers with newline splitting, a heartbeat, a JSON event, and tests
- [x] Cookies out and clearing with tests, using goose-http's validation
- [x] Neither part adds state or work to requests that don't use it
- [x] Directory mount with tests
- [ ] SPA fallback with tests
- [ ] `Cache-Control` per-file hook with tests
- [ ] CORS additions with tests
- [ ] Each helper with a test, or cancelled here with its reason
- [x] `docs/reference.md` updated for each one added
