# 018: Build from the pinned Goose release

Status: in-progress (asked for 2026-10-15)

Goose publishes official releases for Windows, Linux, and macOS. Asked for 2026-10-15:
goose-rest builds from the pinned release by default, as goose-http does since its task
034, and pins a Goose commit only when it really needs one.

`scripts/goose.sh` is goose-http's, copied: it names the release (`v2026.1`) and its
archives' SHA-256 sums, downloads the archive into `build/`, or uses `GOOSE` or
`GOOSE_COMMIT` when set ([setup](../docs/development.md#set-up-the-goose-compiler)).
`scripts/test.sh`, `test-unit.sh`, `test-examples.sh` (but for `PREBUILT=1`), and the
benchmark scripts source it, and `bench/rest.sh` and `bench/all.sh` record
`goose_version` in `env.txt`. `scripts/test-aarch64.sh` cross-builds with the release's
`linux-x64` archive, or builds `GOOSE_COMMIT` in its amd64 container, in place of
building `GOOSE_SRC`'s HEAD. `v2026.1` is `46356c2` plus the release packaging and the
compiler's lookup of its stdlib, and `bc3c1f1`, the pin before it, added only a logo, so
results at either commit still stand.

goose-http had to exclude `build/` in `http.build`, because the unpacked release's stdlib
`extern fn`s otherwise enter its JIT library. goose-rest has no `.build` sidecar and no
`extern fn`, and its suite passes with the release in `build/`, so it needs no exclusion.

## Acceptance criteria

- [x] `scripts/test.sh` passes with `GOOSE` unset, on the release, on macOS arm64
      (2026-10-15).
- [x] With `GOOSE_COMMIT=46356c26a94f0e1723b3b61ad56b93a7da70878f`, the compiler builds
      into `build/` and `scripts/test-unit.sh` and `examples/plain` pass on macOS arm64
      (2026-10-15).
- [x] `scripts/test-aarch64.sh` passes with the release's `linux-x64` compiler, and with
      `GOOSE_COMMIT` built in its container (2026-10-15, Docker Desktop on the Mac).
- [x] Each spike gives its recorded output on `v2026.1`, and its README says so.
- [ ] `scripts/test.sh` passes with the release in WSL.
