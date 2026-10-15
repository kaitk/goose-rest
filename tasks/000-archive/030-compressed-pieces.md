# 030: Compress responses sent in pieces

Status: done (2026-10-15)

`rest::compressed` compresses an answer a route writes whole, but a response the route
begins and sends in pieces (`rest::begin`, `send`, `end`) goes uncompressed, as the
route wrote it. The module's comment and the reference say so. A long export, the
response most worth compressing, is the one that misses out.

goose-http compresses a response in pieces with `http::Compressed`, which holds the
encoder between pieces. goose-rest's module would need its own begin, send, and end
over it, with the `http::Compressed` in the program's state, released at `CLOSED`.

## Acceptance criteria

- [x] Under `rest::compressed`, a response begun with `rest::begin` is sent in the
      coding the request's `Accept-Encoding` picks, with `Content-Encoding` and `Vary`,
      chunked, as goose-http's `http::Compressed` sends it
- [x] The encoder's state lives where the response's later calls (`MORE`) reach it, and a
      program that doesn't compress keeps no byte per connection for it
- [x] The encoder is released at the response's end and at `CLOSED`
- [x] `rest::file`'s responses: decided, and the reason recorded (below)
- [x] Tests cover each coding, a client that goes mid-response, `HEAD`, and a type not
      worth compressing
- [x] The reference's compression section and tutorial page 12 say what's compressed

## How it works

- `rest::begin`, `send`, and `end`, and `on_later`'s `CLOSED`, call four hooks that
  `pieces.goose` declares as generic functions leaving the response as written:
  `begin_coded`, `send_coded`, `end_coded`, and `release_coded`. `compression.goose`
  overloads each for an `Exchange`, and a concrete match wins over a generic one (spec
  §7.1), so a program that imports the module runs its versions, and the core imports
  nothing of goose-compress. The architecture doc records it.
- `compressed` sets a new `Exchange.mode` bit, `OFFERED`, while its block runs, and puts
  its `http::Compression` in a worker global, `rest::offered`; both are restored after
  the block, for nested blocks. `begin` inside it, for a type `http::compressible`
  takes, begins with `http::begin_compressed` when the request takes a coding, and sets
  `CODED` once it holds an encoder. A request that takes none gets `Vary` and keeps the
  length `begin` was given; `begin_compressed` would have dropped it.
- The `http::Compressed`, the coding and the encoder's slot in goose-http's pool, goes in
  `rest::coded`, a per-worker array of entries keyed by the connection's fd. `send`,
  `end`, and `CLOSED` find it by `out.fd` only when `CODED` is set. `end` sends the
  coding's trailer with `http::end_compressed`, and `CLOSED` gives the encoder back with
  `http::release_compressed`, both freeing the entry. goose-http calls `CLOSED` before it
  closes the fd, so a reused fd never finds a stale entry.
- `rest::file` stays as it is, inside `compressed` too: it begins with `http::begin`, not
  `rest::begin`. Compressed on the fly, a file would lose its `Content-Length`, its
  ranges and their 206, and the epoll loop's `sendfile`; goose-http's `serve_file`
  doesn't compress either, and serves a copy stored compressed with
  `http::open_precompressed`.
- Tests: `test/test_compression.goose` checks the bytes of each coding against an encoder
  run the same way, `HEAD`, a request that takes no coding, `image/png`, a connection
  that closes mid-response, a failure mid-response, `begin` after a `compressed` block,
  and `rest::file` inside one, and that every encoder is back after each.
  `examples/compress`'s `/v1/export` has curl decode a gzip and a deflate export to the
  identity's checksum.

## Cost

- Per connection slot: no bytes. `Exchange` stays 42 bytes; `OFFERED` and `CODED` are
  spare `mode` bits.
- Per request, for every program: `begin` checks `cx.ex`, and `send` and `end` check
  `CODED`. A program that doesn't import the module calls the generic hooks, which
  inline to nothing.
- Per response compressed at once, in each worker: a 13-byte entry in `rest::coded`,
  and goose-http's pooled encoder, 460,406 bytes for gzip and deflate and 1,010,955 for
  zstd (goose-http's task 022), built once and reset for each response after. Each
  `send` scans `rest::coded` for the fd: one entry per response compressed at once.
- Each piece is compressed and flushed on its own, as goose-http's `send_compressed`
  does, so small pieces compress less well than one answer written whole.

## Alternatives not taken

- The `http::Compressed` in the program's state, with goose-rest's own
  `begin_compressed`, `send_compressed`, and `end_compressed`: no hooks, but three more
  calls, a field the program keeps, and a release it must remember at `CLOSED`.
- A field in `Exchange`: no lookup, but 9 bytes per connection slot for every program.
- The slot in a spill run, as task 025 keeps the middleware's fields: the exchange's
  `at`, `cap`, and `head` are taken by a kept run within the call that begins the
  response, and by `len` and `limit` while a body is read beside it.
- Left open: `rest::file` could open a stored compressed copy with
  `http::open_precompressed`, at the cost of a `stat` per coding the request takes.
