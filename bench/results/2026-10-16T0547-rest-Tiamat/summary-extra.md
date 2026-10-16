Requests per second, median (range of runs), and the server's CPU time per request.

### Tier F

| Server | root | id | json | Peak RSS |
|---|---:|---:|---:|---:|
| goose-uring-bare | 505.2K (503.6K-505.3K), 7.9 µs | 498.4K (493.8K-502.5K), 8.0 µs | 431.2K (427.7K-438.3K), 9.2 µs | 10 MB |
| goose-epoll-bare | 409.7K (406.0K-414.7K), 9.8 µs | 397.3K (397.2K-406.7K), 10.1 µs | 343.2K (341.6K-347.2K), 11.7 µs | 4 MB |
| goose-uring-rest | 508.0K (497.9K-513.2K), 7.8 µs | 493.9K (489.8K-503.1K), 8.1 µs | 429.9K (428.7K-434.3K), 9.3 µs | 10 MB |
| goose-epoll-rest | 403.8K (397.0K-412.4K), 9.9 µs | 390.2K (387.9K-396.2K), 10.3 µs | 342.4K (336.3K-348.0K), 11.7 µs | 4 MB |

### Tier R

| Server | routes | Peak RSS |
|---|---:|---:|
| goose-uring-rest | 332.3K (328.8K-334.0K), 12.0 µs | 10 MB |
| goose-epoll-rest | 265.4K (262.8K-267.6K), 15.1 µs | 4 MB |
| goose-uring-rest-gen | 465.5K (462.9K-468.3K), 8.6 µs | 10 MB |
| goose-epoll-rest-gen | 369.0K (367.6K-376.2K), 10.9 µs | 4 MB |

### Tier M, against tier A

| Server | a | m | Peak RSS |
|---|---:|---:|---:|
| goose-uring-rest | 581.2K (575.7K-591.4K), 6.8 µs | 489.3K (479.3K-492.7K), 8.2 µs | 13 MB |
| goose-epoll-rest | 441.1K (425.9K-445.5K), 9.1 µs | 358.1K (357.3K-359.1K), 11.2 µs | 8 MB |
