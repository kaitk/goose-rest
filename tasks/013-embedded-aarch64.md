# 013: A device example, and the examples on arm64

Status: in-progress

Show goose-rest on a 64-bit ARM embedded Linux board, as goose-http's task 029 does for
goose-http (2026-10-14): an example of a device's HTTP API from a schema, and a script
that cross-builds the examples and runs their checks on arm64 in Docker. goose-http's
`docs/embedded.md` covers cross compilers, Yocto SDKs, and what the board needs; this
task doesn't repeat it.

## Acceptance criteria

- [x] `examples/device/`: from `api.json`, temperature and uptime read from sysfs and
      `/proc`, settings with bounds that set an LED's brightness through sysfs, a
      firmware upload with its own `x-body-limit`, a bearer token on writes, CORS, and a
      page; one worker and small limits; in `scripts/test-examples.sh`
- [x] `scripts/test-aarch64.sh`: builds a Linux Goose compiler from a copy of the
      checkout, cross-builds the examples, runs `scripts/test-examples.sh` on them on
      arm64, and prints each one's peak RSS
- [x] The run below, beside goose-http's device
- [ ] Run on an x86-64 host, where arm64 is emulated, and on a board

## Left out

- Server-Sent Events. goose-http has them at the pin (`http::later`, `http::send`), but
  `rest::serve` answers a route's `TIMEOUT` with 504, for `rest::ask`, and has no
  stream route.
- A GPIO line. goose-http's device sets one through C, and goose-rest has no C.
- A raw firmware body. The generator takes JSON request bodies only, so the image comes
  as base64 in JSON. `api::MAX_BODY` is never below 1 MB, the default route's limit,
  though every body route here takes less.

## Arm64 in Docker (2026-10-14)

`scripts/test-aarch64.sh`, with `GOOSE_SRC` at Goose `46356c2` and `GOOSE_HTTP` at
goose-http `61cffab`. The machine is an Apple M1 Pro (10 cores) on macOS 26.3.1, with
Docker Desktop 29.8.2, whose Linux VM runs kernel 7.0.14-linuxkit on aarch64. The
examples were built with aarch64-linux-gnu-gcc 15.2.0 (Ubuntu 15.2.0-16ubuntu1) in an
amd64 `ubuntu:26.04` container under Rosetta, and run in an arm64 `ubuntu:26.04`
(26.04.1) container. On this host that container runs natively, so no qemu was involved
and the numbers include no emulator. Docker blocks io_uring, so `rest::serve` and
goose-http's `LOOP=uring` ran on the emulated ring over epoll.

Each goose-rest example serves on one worker. `test-examples.sh` passed for every
example. Peak RSS is VmHWM in kB, read once the example answers `/health` and again
after its requests. One run.

| Example | At start | After the requests |
|---|---|---|
| `device` | 3,956 kB | 4,728 kB |
| `plain` | 3,784 kB | 7,900 kB |
| `schema` | 3,800 kB | 5,872 kB |
| `waiting` | 5,904 kB | 5,988 kB |
| goose-http's `device`, `LOOP=uring`, `WORKERS=1` | 5,872 kB | 5,876 kB |
| goose-http's `device`, `LOOP=epoll`, `WORKERS=1` | 3,836 kB | 3,836 kB |

The two devices don't serve the same configuration, so the comparison is between
programs, not frameworks:

- goose-rest's device sets `max_conns: 64`, `ring_entries: 256`, and `ring_buffers:
  64`, and opens no mailbox. goose-http's keeps the defaults, 4,096 entries and 256
  buffers of 4 KB, with a mailbox and 64 timers for its event streams. At start,
  goose-rest's device on the ring takes 1,916 kB less than goose-http's on the ring, and
  120 kB more than goose-http's on epoll.
- goose-rest's device grows 772 kB over its requests: the 253 KB firmware body is
  gathered into the worker's spill, and its 190,000 decoded bytes into an array the handler grows.
  goose-http's checks send no body larger than its read buffer.
- `plain` and `schema` grow most because their checks send bodies of 1.5 to 3 MB.

goose-http's task 029 ran its examples on another machine: x86-64 (Ryzen 7 5800X3D, 16
logical CPUs) under WSL2, with arm64 emulated by qemu, at 16 workers each. Its `device`
peaked at 16,556 kB with `LOOP=uring` and 16,040 kB with `LOOP=epoll`, of which about
13,000 kB was qemu's own. Those numbers don't compare with the table above.
