# 030: Compress responses sent in pieces

Status: todo (found 2026-10-15)

`rest::compressed` compresses an answer a route writes whole, but a response the route
begins and sends in pieces (`rest::begin`, `send`, `end`) goes uncompressed, as the
route wrote it. The module's comment and the reference say so. A long export, the
response most worth compressing, is the one that misses out.

goose-http compresses a response in pieces with `http::Compressed`, which holds the
encoder between pieces. goose-rest's module would need its own begin, send, and end
over it, with the `http::Compressed` in the program's state, released at `CLOSED`.

## Acceptance criteria

- [ ] Under `rest::compressed`, a response begun with `rest::begin` is sent in the
      coding the request's `Accept-Encoding` picks, with `Content-Encoding` and `Vary`,
      chunked, as goose-http's `http::Compressed` sends it
- [ ] The encoder is released at the response's end and at `CLOSED`
- [ ] Tests cover each coding, a client that goes mid-response, and `HEAD`
- [ ] The reference's compression section and tutorial page 12 say what's compressed
