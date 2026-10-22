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

## Found from the code (2026-10-22)

Not measured: this compares the two tier servers' code, without perf.

The first candidate doesn't hold as written. goose-http's tier D also holds a batch or
a form whole: one that came with its head is answered at once, and one that didn't is
joined piece by piece into a spool (`join` in its `bench/rest/goose/app.goose`) and
answered at its END. The forms role's requests are four in seven batches of
200-500 KB, which never come with the head, so both servers gather most of them.

What differs for a body that didn't come whole:

- Per piece, goose-rest does no more. A body with a Content-Length gets a run of its
  exact size, so `gather_piece` copies each piece without growing the run, where
  goose-http's spool starts at 16 KB and doubles, copying each body about twice.
- Per request, goose-rest does more. The route runs twice, `rest::body` leaving it
  the first time, so the second call routes, checks the bearer token and the type
  again; `head_of` parses the head again from its copy; and `fits` and `track` scan
  the worker's runs. This is small beside parsing a batch's JSON, so it probably
  isn't the whole rate gap.
- goose-rest gathers into the package's spill, a local of each worker's `serve`,
  while the uploads' spools are in the tier server's `spill`; goose-http keeps both in
  its one spill. Two spills keep two peaks, which could hold more memory, but would
  do so on io_uring as well, where peak RSS is even. So it doesn't explain epoll's
  17 MB alone.

Next, on Linux: `perf record` of both servers in the mixed run on each loop, to see
where goose-rest's extra time goes; and, as a check of the package's share, the tier
server's batch and form routes with `rest::body_in_pieces` and a spool, as goose-http
reads them, measured once and not kept, since the tier measures `rest::body`.
