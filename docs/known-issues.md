# Known issues

Environment traps and incidents met while building, testing, and benchmarking
goose-rest, grouped by platform. A date records when an incident happened. Setup steps
are in [development](development.md). goose-rest runs goose-http's loops and many of
its scripts, so
[goose-http's known issues](https://github.com/kaitk/goose-http/blob/main/docs/known-issues.md)
apply here too.

## Goose

Traps met while writing the generator and its tests (2026-10-13):

- A `"""` string must start its text on the line after the `"""` if it spans lines.
  Keep a one-line JSON document on one line.
- A slice that starts as `""` can't later point into a buffer, nor into the JSON
  document: start it from that buffer (`r.text[..0]`), or return it from a function
  (spike 05).
- An optional reference field is rebound with `.=`, not assigned: `ty.minimum .= n`.
- Mutually recursive emitters need `recursive fn`; split them instead where one level
  is enough (`write_value` and `write_one`).

## Tests

- `examples/device` reads its fake sysfs from `build/examples/` and takes paths of up to
  1 KB, so a checkout deeper than that fails its run as "no answer on port", with
  "THERMAL is too long" in `build/examples/device.log`.
- `scripts/test-examples.sh` serves from port 18081 up, and a port in use there fails
  the run.

## WSL2 on Windows

- Windows npx on WSL's `PATH` accepts neither the Linux paths the suite passes nor its
  Linux TypeScript package. Put Linux Node and npx first.
- Ubuntu's Node 22.22.1 was built without TypeScript support, despite its version;
  Node 24.14.1's Linux distribution runs the `.mts` files.
- Git Bash's converted paths differ from the exact generator diagnostics the suite
  checks, so the suite fails there. Run it in WSL.
- The Ubuntu distribution runs as `root`. Without a global Git identity there, Git
  records the author as `root@<hostname>`, so set `user.name` and `user.email` in WSL
  before committing from it (2026-10-14).

## Benchmarks

Traps met counting the routers' instructions (2026-10-13, h2load 1.70.0):

- h2load counts a 4xx response as "failed", not "succeeded", and `count.sh` exits unless
  every request succeeded. `bench/routes.sh` checks h2load's status-code line instead.
- `h2load -d /dev/null` fails with "Could not mmap file" at `-t 8`; an empty regular
  file can't be mapped either.
- h2load's POSTs ran at a tenth of its GETs' rate against the same server, which kept
  the connection open: about 35,000 requests a second against 330,000. The kernel's
  share then buries a router's cost, so `bench/routes.sh` sends only GETs.

### The REST benchmark on macOS

What `bench/rest.sh check` met on macOS (2026-10-14):

- dusty pins Zig 0.16.0, and Homebrew's `zig` is 0.17.0. ziglang.org's 0.16.0 tarball
  for `aarch64-macos` works; set `ZIG` to its `zig`. zio 0.19.1 runs on kqueue.
- Zig 0.16 fetches packages into `zig-pkg/` beside `build.zig.zon`, so `bench/rest.sh`
  builds dusty from a copy in `CACHE`, and passes tier R's route list with `-Dgithub`.
- In zsh, `env $v` passes a variable holding `A=1 B=2` as one argument; `bench/rest.sh`
  is `sh`, where it splits.

## ARM under Docker

What `scripts/test-aarch64.sh` met (2026-10-14, Docker Desktop 29.8.2 on an Apple M1
Pro):

- On an arm64 host, the arm64 container runs natively in Docker Desktop's VM, and the
  amd64 one under Rosetta. On an x86-64 host it's the reverse: the checks run under
  qemu, whose own memory adds to each RSS.
- The compiler fetches goose-http with git into `build/aarch64/goose-home`, and git
  refuses the mounted directory ("detected dubious ownership"), as it refuses the clone
  of a `GOOSE_COMMIT` build there (2026-10-15). The script sets `safe.directory` through
  `GIT_CONFIG_*` variables for both.
- Docker's seccomp profile blocks `io_uring_setup`, so `rest::serve` runs on goose-http's
  emulated ring over epoll there.
