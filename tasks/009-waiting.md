# 009: Waiting on another thread

Status: todo

A handler that asks another thread and a case function that answers when the reply
arrives, on spike 06's result.

## Acceptance criteria

- [ ] `rest::ask`, and resuming through the application's `Waiting` enum
- [ ] An example with a database thread, tested over HTTP
- [ ] Replies larger than a mailbox slot, by whatever spike 06 settles
- [ ] A route that never waits keeps nothing on the connection
