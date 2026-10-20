# 058: Uploads beside forms

Status: todo (asked for 2026-10-20)

With tier D's forms running beside its uploads, goose-rest serves fewer of both than
goose-http alone, on both loops, and holds more memory on epoll. Alone, uploads are
even. From the nightly session `2026-10-20T0854-Tiamat` (`bench/all.sh`; Ryzen 7
5800X3D, WSL2 kernel `6.18.54.1-microsoft-standard-WSL2`, goose-rest `62c340d`,
goose-http `0a016bb0`, Goose `f114b5a`, 4 workers; `docs/benchmarks.md` has the
method), goose-http alone against goose-rest:

| Loop | Uploads/s | Forms/s | Forms p99 | Peak RSS |
|---|---:|---:|---:|---:|
| io_uring | 170-175 against 150-156 | 7.7-7.8 K against 6.7-6.9 K | 64.7-67.1 against 74.3-78.3 ms | 125 against 123 MB |
| epoll | 123-125 against 108-116 | 7.7-8.0 K against 7.2-7.3 K | 79.9-86.0 against 86.4-92.2 ms | 132 against 149 MB |
| Alone, io_uring | 1.1-1.2 K against 1.1 K | | | 71 against 71 MB |
| Alone, epoll | 1.1-1.2 K against 1.1 K | | | 69 against 70 MB |

`docs/benchmarks.md` records the io_uring gap under "Where goose-rest loses".

Since the gap needs both workloads at once, the cause is in how they share a worker.
A first candidate, not measured: whether tier D's forms read their bodies whole
(`rest::body`) where goose-http's tier D reads them a piece at a time, as uploads
have done since task 021. A form held whole delays the upload pieces queued behind
it, and on epoll the gathered bodies would explain the 17 MB.

## Acceptance criteria

- [ ] The cause found and measured on Linux, for the rate on both loops and for
      epoll's memory
- [ ] Fixed in the package or the tier server, or recorded here with the reason it
      stays
- [ ] Uploads beside forms rerun against goose-http alone, recorded in
      `docs/benchmarks.md`
