# 053: A Goose design note for a contained scope

Status: todo, as a design note only; not to be proposed to Goose yet (2026-10-19).

Task 051 contains a bug to its thread: a worker's abort drops all its connections. A
scope that an abort ends, as `return … from` ends a call (spec §7.9), would contain it
to one request or one job, as Hono, Spring, and axum do, and let its fallback roll back
on the same connection. Expected errors don't need it: `return … from` already carries
them across any depth (task 052).

The note to write:

- **Semantics.** A failed check inside a contained scope acts as `return message from`
  that scope. Stacks owned by outer live values keep their tops, so an outer resizable
  that grew keeps its elements; the scope's other stacks go back to where they stood at
  its start (§1.3, §10.3). Outer state the scope changed stays changed. Stack overflow,
  `exit`, and the runtime's own failures still end the process, as for #38.
- **Implementation.** `_setjmp` at the scope, through #38's `gs_contain`, with the scope
  outlined into its own C function so that no local is read after the jump. A
  propagate flag, as `return … from` uses, would add a branch after nearly every call.
  `return … from` out of the scope pops its handler.
- **Cost.** One `_setjmp` per scope entry, measured against a request on tier A.
- **Use.** `rest::serve` wraps each handler call and answers 500; `http::lane` wraps
  each job.

## Acceptance criteria

- [ ] The note in this task, with a prototype on a Goose branch and its cost measured
- [ ] A decision whether to propose it, after task 051 has run in an application
