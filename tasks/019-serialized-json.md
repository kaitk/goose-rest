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

## Acceptance criteria

- [ ] The cause is measured, with instruction counts on tier B or C's serialized routes
- [ ] The fix is in the generated writers or the package, so programs get it, and
      `scripts/test.sh` passes
- [ ] Tiers B and C serialized rerun on Linux against goose-http alone, recorded in
      `docs/benchmarks.md`
