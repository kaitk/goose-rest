# 023: Read a body and send a response in pieces

Status: todo (found 2026-10-15)

goose-rest gathers a request body whole, up to its limit (`rest::body`), and sends a
response whole, but for `rest::relay`'s pieces of a service's reply. A route can't read
an attachment of any size as it arrives, or send an export, a file, or events in pieces
as the loop takes them, though goose-http does all of these
([patterns](https://github.com/kaitk/goose-http/blob/main/docs/patterns.md), "Request
bodies" and "Long responses"). The tutorial lists its pages 11, "Bodies read as they
arrive", and 12, "Long responses and files", as TBD until this lands (task 016), and the
README's status table names both as not yet.

## Acceptance criteria

- [ ] A route reads a body in pieces as they arrive, with a limit, inside `rest::route`
- [ ] A route sends a response in pieces as the loop calls for more, and a file
- [ ] The tutorial's pages 11 and 12, each with a program `scripts/test.sh` builds and
      requests, and the index links them
- [ ] The README's status rows say what works
