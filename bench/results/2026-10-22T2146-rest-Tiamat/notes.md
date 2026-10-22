# Measurement notes

Plod's REST steps of `bench/all.sh`, run as a session of their own, `2026-10-22T2146-Tiamat`,
measured Plod `556445e` (`v0.4.0` with docs and comments only) and goose-http `a7ce7d12`
(`v0.5.4` with comments only) with Goose `v2026.3`. goose-http's own steps ran in the
session before, `2026-10-22T2042-Tiamat`, which was stopped at its REST step: it had
pulled goose-rest `v0.3.3`, a tag behind. In this session Plod's tests failed only in
`test/tls/choose` and `test/tls/tls_served`, at both levels, with `listen: Operation not
supported`: they listen on Unix sockets, which WSL's `/mnt/c` can't hold. The suite ran
from the checkout there. All benchmark servers passed the workload checks.

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
| goose-uring | 1,106.68; 1,113.93; 1,119.04 | 1,113.93 |
| goose-epoll | 1,125.17; 1,112.23; 1,119.34 | 1,119.34 |
| goose-uring-rest | 1,124.64; 1,084.56; 1,093.02 | 1,093.02 |
| goose-epoll-rest | 1,123.86; 1,140.01; 1,121.08 | 1,123.86 |

`count.txt` comes from `bench/rest.sh count`, as on 2026-10-20: one epoll worker on
CPU 0, h2load on CPUs 4-15, 256 connections, 16 requests in flight on each, 10 million
requests, one run per case.

Every saturation rate is lower than in session `2026-10-20T0854-Tiamat`: goose-http
alone by 2.1-5.8% on io_uring and 2.4-7.4% on epoll, and Plod by 1.3-6.4% and
0.8-6.8%. The user instructions per request in `count.txt` are within 2.1% of that session's in every
case but tier M, so the rates fall with the machine's drift that goose-http's record of
2026-10-22 measures: `v0.4.3`, rebuilt the same night, took 3-4% more cycles per
request than on 2026-10-20. Tier M is the exception: 5,323.9 user instructions and
1,927.7 user cycles per request, against 4,968.4 and 1,536.5 on 2026-10-20 at `v0.2.1`
and 5,030.4 and 1,560.4 in `2026-10-20T2001-rest-Tiamat`, so it grew by 5.8% in
instructions and 23.5% in cycles after that session.
