# 002: Spikes for resuming and for the format hook

Status: todo

Two assumptions in the architecture doc have no spike yet.

## Acceptance criteria

- [ ] Spike 06: a route asks another thread over goose-http's mailbox with a
      `to_bytes` job, keeps a fixed-mode `Waiting` enum in the per-request state, and
      resumes through one case function per variant; a missing case fails to compile
- [ ] Spike 06 records what a reply larger than a mailbox slot needs
- [ ] Spike 07: `rest::json`, generic and in namespace `rest`, finds a `format`
      overload declared in the value's namespace, for a nested type too
- [ ] Each spike's README has its command, Goose commit, and verdict, and the
      architecture doc's spike table is updated
