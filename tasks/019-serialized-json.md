# 019: Close the serialized JSON loss against goose-http

Status: in-progress (asked for 2026-10-15; the package's half is done, the Linux rerun
shows the loss gone (2026-10-20), and the cause's instruction count is open)

On tiers B and C serialized, goose-rest's tier server loses 8-15% to goose-http's, and
tier C takes 74.9 µs of CPU per request against 64.2
([benchmarks](../docs/benchmarks.md#where-goose-rest-loses)). The templated tiers,
whose JSON is prebuilt, lose only 1.3-3.1%, so the loss is in serializing.

The likely cause, not yet measured: goose-http's tier server looks for a string's
escapes with std's `find_any` before calling `json::format_string`, which made its B and
C 11-23% faster (goose-http `b03a446`), while goose-rest's
(`bench/rest/goose-rest/main.goose`) calls `json::format_string` on every string. If the
scan is the fix, it belongs where every program gets it: the generated writers, and
`rest::json`'s path, not the tier server alone.

## Where it stands (2026-10-15)

The scan is in both benchmark servers only: goose-rest's tier server took goose-http's
`json_string` with task 020's fix 1, after v0.0.1, so the gap in the published run
(goose-rest v0.0.1: tiers B and C serialized 9-15% behind) should close there at the
next run. Neither package has it:

- goose-http's `http::json_string` (`message.goose`) loops a byte at a time, and its
  tier server keeps a private copy with the scan.
- goose-rest's generator writes `json::format_string` in every generated writer
  (`gen/emit.goose`), and `rest::json` reaches the same, so programs pay the loop.
- The stdlib's `json::format_string` is that loop: a finding for
  `docs/goose-findings.md`, worked around here.

goose-http's task 033 put the scan where it measured the loss, its tier server, and
recorded the stdlib's side as a finding; moving it into `http::json_string` was left
undone, not decided against.

So the fix, one implementation used everywhere (2026-10-15): goose-http's
`http::json_string` takes the scan, and its tier server drops its copy; goose-rest's
generator, `rest::json`, its error bodies, both tier servers, the tutorial's programs,
and the examples call `http::json_string`, so no code in either repository calls
`json::format_string` for a string; every `_gen.goose` regenerated. It starts after the test migrations (this repository's task
038, goose-http's task 041), which reorganize the tests it changes (2026-10-15).

## Done (2026-10-15)

goose-http v0.3.3's `http::json_string` has the scan, and its output equals
`json::format_string`'s. With the pin at v0.3.3, every JSON string goose-rest writes goes
through it: the generator's writers (`gen/emit.goose`, which also imports `http` into a
generated file with a string field to write), `rest::error_body` (`runtime.goose`), the
tutorial's and the best practices' programs, `examples/plain`, the runtime's tests, and
the tier server, whose private `json_string` and `JSON_ESCAPES` are gone. Every
`_gen.goose` was regenerated: only the call and the import changed, and no expected
output did. The tier server passes goose-http's `check.py` on tiers A to D and
`bench/rest/tiers/check.py` on F, R, and M on macOS. Spike 07 keeps
`json::format_string`: it checks the language, and imports no goose-http.

## Acceptance criteria

- [ ] The cause is measured, with instruction counts on tier B or C's serialized routes
      (open: goose-http's `bench/count.sh` sends no cookie or bearer token, so B and C
      answer 401 to it; see "On Linux")
- [x] The fix is in the generated writers or the package, so programs get it, and
      `scripts/test.sh` passes
- [x] Tiers B and C serialized rerun on Linux against goose-http alone, recorded in
      `docs/benchmarks.md` (2026-10-20)

## On Linux (2026-10-20)

The nightly session `2026-10-20T0854-Tiamat` (`bench/all.sh`; Ryzen 7 5800X3D, WSL2
kernel `6.18.54.1-microsoft-standard-WSL2`, goose-rest `62c340d`, goose-http `0a016bb0`,
Goose `f114b5a`, 4 workers, the fixed rates in `docs/benchmarks.md`), goose-rest
against goose-http alone, serialized:

| Tier | io_uring | epoll |
|---|---:|---:|
| B | 317 K against 315 K (+0.3%) | 243 K against 245 K (-0.6%) |
| C | 63.2 K against 63.3 K (-0.2%) | 61.3 K against 61.7 K (-0.6%) |

Tier C's CPU per request is 63.3 against 63.2 µs on io_uring and 65.3 against 65.0 on
epoll, where it was 74.9 against 64.2. The loss is gone. Task 020's fix 1 changed the
tier server's records in the same span, so the rerun alone doesn't show which change
closed it. The open criterion needs a header option in `bench/count.sh`, or perf
over a `tier-b.lua` run, at a commit before `ed7ebfc` and one after it. With the loss
gone, the criterion could be dropped instead; that is the user's call.
