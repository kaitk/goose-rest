# 058: Uploads beside forms

Status: in-progress (asked for 2026-10-20). The memory gap's cause is found
("Measured on Linux"); its fix is goose-http's gather pool (its task 059), and the
rerun comes after goose-rest adopts it.

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

## Measured on Linux (2026-10-22)

`bench/058-run.sh` on the branch `058-linux-run` (`bf03a53`), which isn't merged:
Enkidu, a Ryzen 7 PRO 6850U, 16 logical CPUs, WSL2 kernel
`6.18.54.1-microsoft-standard-WSL2`; goose-http `0a016bb0`, Goose v2026.3, gcc 15.2;
4 workers on CPUs 0-3, wrk on 4-15 with 8 threads; one round of 10 s after 3 s of
warm-up. "Pieces" is goose-rest's tier server with the batch and the form read by
`rest::body_in_pieces` into the tier's own spool, as goose-http's server reads them.

| Loop | Server | Uploads/s beside forms | Forms role req/s | Forms p99 ms | Peak RSS MB |
|---|---|---:|---:|---:|---:|
| epoll | goose-http | 80 | 5.1 K | 122 | 129 |
| epoll | goose-rest | 83 | 5.3 K | 114 | 150 |
| epoll | pieces | 77 | 4.8 K | 129 | 131 |
| io_uring | goose-http | 104 | 4.7 K | 117 | 125 |
| io_uring | goose-rest | 100 | 4.5 K | 111 | 121 |
| io_uring | pieces | 96 | 4.5 K | 112 | 123 |

Alone, uploads were 668-724 a second and 70-72 MB for all six.

- **The rate gap doesn't show on this machine.** goose-rest serves as many uploads
  and forms as goose-http alone on both loops, within one round's noise. Whether the
  desktop's gap was that machine's or that session's is open: a rerun there with
  three rounds settles it.
- **Epoll's memory gap does, and its cause is the gathered bodies' own spill.** The
  same server holds 150 MB with `rest::body` and 131 MB with the bodies in the tier's
  spool, against goose-http's 129: about 20 MB more for a second arena per worker,
  as the desktop's 17 MB. io_uring is even, on this run as on the desktop's; why only
  epoll's peak grows is open.
- **The profiles show no cost of the route's second run, nor of the budget's
  scans.** `rest_gather_piece` takes about 10% of samples, as goose-http's `join`
  does, both copying; JSON parsing takes most of the rest. `tier_c` takes about 5%
  in goose-rest with `rest::body` and in pieces alike, though pieces never runs a
  route twice, and none of `spill_end`, `free_at`, or `track` is among the top 25
  symbols. Routing a gathered body once isn't worth its machinery for this tier.

The fix: gathered bodies in goose-http's per-worker pool, which a budget bounds, as
goose-http's task 059 designs it, so a worker keeps one arena. Then this run again,
against goose-http alone, with three rounds.
