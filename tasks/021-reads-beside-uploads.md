# 021: Cut the latency of reads beside uploads

Status: todo (asked for 2026-10-15)

With uploads running, tier C's reads at a fixed 1,700 a second reach a p99 of 20.4-28.1
ms on goose-rest's io_uring loop against 4.8-7.5 ms on goose-http alone, and 13.8-16.1 ms
on epoll against 0.40-1.35 ms. Alone, the reads' p99 is 0.14-0.96 ms on all four, and
goose-rest serves 11-12% fewer uploads a second
([benchmarks](../docs/benchmarks.md#uploads-and-memory)). It isn't explained yet;
the first thing to check is how goose-rest gathers a long body before the route runs,
which may share a cause with task 020.

## Acceptance criteria

- [ ] The cause is found and measured on Linux
- [ ] Fixed in the package, or recorded with the reason it stays
- [ ] Reads beside uploads and uploads alone rerun against goose-http alone, recorded in
      `docs/benchmarks.md`
