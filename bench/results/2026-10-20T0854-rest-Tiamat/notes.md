# Measurement notes

`bench/all.sh`, session `2026-10-20T0854-Tiamat`, measured goose-rest `62c340d` (`v0.2.1`)
and goose-http `0a016bb0` (`v0.4.3`) with Goose `f114b5a`. Both repositories' tests
had passed on WSL before the session. All benchmark servers passed the workload checks.

Machine: Tiamat, Ryzen 7 5800X3D, 8 cores and 16 logical CPUs, Windows 11,
WSL2 Ubuntu 26.04.1, kernel 6.18.54.1-microsoft-standard-WSL2, gcc 15.2.0.
Four workers on CPUs 0-3; wrk 4.1.0 on CPUs 4-15 with 8 threads and 256 connections.
Each cell uses a fresh server, 5 s warm-up and three interleaved 15 s runs.
Uploads alone use 1 thread and 32 connections. Fixed rates are A 100,000/s,
B 24,000/s and C 1,700/s. `env.txt` records the remaining settings.

The summaries retain the ranges; the uploads-alone medians below retain the precision
of `d-<server>-alone-r<run>.uploads.wrk`'s `Requests/sec` lines:

| Server | Three runs, uploads/s | Median |
|---|---|---:|
| goose-uring | 1,139.71; 1,145.93; 1,151.85 | 1,145.93 |
| goose-epoll | 1,162.13; 1,168.29; 1,136.81 | 1,162.13 |
| goose-uring-rest | 1,106.68; 1,124.01; 1,134.56 | 1,124.01 |
| goose-epoll-rest | 1,141.13; 1,143.31; 1,139.89 | 1,141.13 |

`count.txt` comes from `bench/rest.sh count`: one epoll worker on CPU 0, h2load
on CPUs 4-15, 256 connections, 16 requests in flight on each, 10 million requests,
one run per case, counting user instructions and cycles with perf. Tier F's first
row in each pair is the bare server; tier R's first is the if chain and its second
the generated router.

C templated reaches 155.3 K/s on goose-rest's io_uring loop and 144.3 K/s on epoll,
0.6% and 2.6% below goose-http alone. The previous session measured 142.2 K/s and
132.2 K/s, so both rise by about 9.2%. A, B and F mostly fall between sessions;
the generated R falls 4.1% on io_uring and 1.1% on epoll, while M rises 4.1% and
4.6%. The summaries report all cells, including upload throughput and latency gaps.
