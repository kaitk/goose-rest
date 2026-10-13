# 005: Extractors

Status: todo

Typed access to the request, each failure answered by `rest::fail`.

## Acceptance criteria

- [ ] Path parameters as integers or strings, query parameters, headers, and cookies
- [ ] A JSON body into a struct through `rest::take<T>`, with 400 and field errors for
      an invalid body and 415 for another media type
- [ ] Application extractors declared as `fn rest::from_request`, and the generator
      writes them for its types
- [ ] `rest::once`, a lazy value computed on first call and kept for the request
- [ ] A test for each failure's status and body
