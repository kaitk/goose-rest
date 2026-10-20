Requests per second, median (range of runs), and the server's CPU time per request.

### Tier F

| Server | root | id | json | Peak RSS |
|---|---:|---:|---:|---:|
| goose-uring-bare | 508.6K (505.9K-509.6K), 7.8 µs | 500.3K (499.1K-501.2K), 8.0 µs | 434.6K (431.9K-434.7K), 9.2 µs | 10 MB |
| goose-epoll-bare | 407.1K (403.3K-407.8K), 9.8 µs | 395.0K (393.8K-395.3K), 10.1 µs | 338.8K (326.1K-341.6K), 11.8 µs | 4 MB |
| goose-uring-rest | 510.6K (507.2K-511.5K), 7.8 µs | 497.8K (497.8K-501.8K), 8.0 µs | 429.6K (429.5K-431.0K), 9.3 µs | 10 MB |
| goose-epoll-rest | 401.6K (392.9K-404.1K), 10.0 µs | 393.9K (388.4K-397.5K), 10.2 µs | 336.5K (335.6K-336.9K), 11.9 µs | 4 MB |

### Tier R

| Server | routes | Peak RSS |
|---|---:|---:|
| goose-uring-rest | 331.3K (330.0K-332.1K), 12.1 µs | 10 MB |
| goose-epoll-rest | 263.5K (263.3K-264.8K), 15.2 µs | 4 MB |
| goose-uring-rest-gen | 471.1K (469.1K-473.4K), 8.5 µs | 10 MB |
| goose-epoll-rest-gen | 375.3K (372.8K-378.1K), 10.7 µs | 4 MB |

### Tier M, against tier A

| Server | a | m | Peak RSS |
|---|---:|---:|---:|
| goose-uring-rest | 577.2K (576.7K-578.3K), 6.9 µs | 508.8K (505.4K-513.5K), 7.8 µs | 13 MB |
| goose-epoll-rest | 420.8K (420.2K-429.1K), 9.5 µs | 370.2K (369.2K-372.4K), 10.8 µs | 8 MB |
