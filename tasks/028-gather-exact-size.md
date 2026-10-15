# 028: Gather a body of known length in one run of its exact size

Status: todo (asked for 2026-10-15)

`rest::body` gathers a long body into the worker's spill, growing the run by doubling
from 16 KB as pieces come (`gather_piece` in `runtime.goose`). A body with a
`Content-Length` is copied once per doubling, and its run ends up to twice its size,
which the spill keeps as its high-water mark for the worker's life (task 020's
findings). A body whose length is known can take one run of that size at its first
piece: no growth copies and no slack. A chunked body still grows as now.

## Acceptance criteria

- [ ] A body with a `Content-Length` is gathered into one run of its head and body's
      exact size, allocated at the first piece, with no copy as it grows; a chunked
      body grows as before
- [ ] Unit tests cover a body with a length, a chunked one, and one over its limit
- [ ] The spill's peak for task 020's upload workload is measured before and after, with
      how it was measured
