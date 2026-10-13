# 002: Spikes for resuming and for the format hook

Status: done

Two assumptions in the architecture doc have no spike yet.

## Acceptance criteria

- [x] Spike 06: a route asks another thread over goose-http's mailbox with a
      `to_bytes` job, keeps a fixed-mode `Waiting` enum in the per-request state, and
      resumes through one case function per variant; a missing case fails to compile
- [x] Spike 06 records what a reply larger than a mailbox slot needs
- [x] Spike 07: `rest::json`, generic and in namespace `rest`, finds a `format`
      overload declared in the value's namespace, for a nested type too
- [x] Each spike's README has its command, Goose commit, and verdict, and the
      architecture doc's spike table is updated
