# 020: Find where goose-rest's memory goes

Status: todo (asked for 2026-10-15)

At saturation on io_uring, goose-rest holds 2.0-6.7 times goose-http's peak RSS: 33 MB
against 12 on tier A, 96 against 30 on B, 140 against 71 on C, and 387 against 58 on C
with templates. Uploads alone: 385-422 MB against 69-70
([benchmarks](../docs/benchmarks.md#uploads-and-memory)). It isn't explained yet.
Candidates to check: bodies gathered whole up to a route's limit, per-request state
and scratch kept per connection, and the tier server's own records.

## Acceptance criteria

- [ ] Each tier's extra memory is attributed to its source, measured on Linux
- [ ] What belongs to the framework is cut or recorded with the reason it stays
- [ ] Peak RSS rerun on Linux against goose-http alone, recorded in
      `docs/benchmarks.md`
