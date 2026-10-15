# 019: Close the serialized JSON loss against goose-http

Status: todo (asked for 2026-10-15)

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

## Acceptance criteria

- [ ] The cause is measured, with instruction counts on tier B or C's serialized routes
- [ ] The fix is in the generated writers or the package, so programs get it, and
      `scripts/test.sh` passes
- [ ] Tiers B and C serialized rerun on Linux against goose-http alone, recorded in
      `docs/benchmarks.md`
