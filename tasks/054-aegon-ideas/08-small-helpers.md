# 08: Small helpers

Status: todo

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
  `http::set_cookie`, which already checks names, values, and attributes. Add
  `Partitioned` (CHIPS) to goose-http's `Cookie` if it's missing.
- **CORS:**
  - origin patterns (`https://*.example.com`, `http://localhost:*`), matched on the
    whole scheme and host, so `https://example.com.attacker.com` fails
  - a validator function, for tenants' domains
  - `Access-Control-Allow-Private-Network`
  - exposed headers
  - permissive and strict presets
  - the origin echoed with `Vary: Origin` whenever credentials are allowed

## Acceptance criteria

- [ ] Each helper with a test, or cancelled here with its reason
- [ ] `docs/reference.md` updated for each one added
