Requests per second, median (range of runs), and the server's CPU time per request.

### Tier F

| Server | root | id | json | Peak RSS |
|---|---:|---:|---:|---:|
| goose-uring-bare | 517.7K (517.3K-518.4K), 7.7 µs | 511.2K (503.1K-512.1K), 7.8 µs | 439.2K (433.2K-443.3K), 9.1 µs | 10 MB |
| goose-epoll-bare | 412.7K (410.6K-414.6K), 9.7 µs | 402.9K (401.5K-406.0K), 9.9 µs | 345.3K (341.3K-346.9K), 11.6 µs | 4 MB |
| goose-uring-rest | 516.9K (513.1K-517.1K), 7.7 µs | 504.5K (503.5K-508.7K), 7.9 µs | 429.2K (425.4K-432.7K), 9.3 µs | 10 MB |
| goose-epoll-rest | 404.9K (401.1K-408.3K), 9.9 µs | 396.0K (394.6K-396.9K), 10.1 µs | 345.1K (331.5K-345.2K), 11.6 µs | 4 MB |

### Tier R

| Server | routes | Peak RSS |
|---|---:|---:|
| goose-uring-rest | 325.2K (321.3K-328.6K), 12.3 µs | 10 MB |
| goose-epoll-rest | 263.1K (261.2K-264.5K), 15.2 µs | 4 MB |
| goose-uring-rest-gen | 469.7K (469.4K-470.3K), 8.5 µs | 11 MB |
| goose-epoll-rest-gen | 372.8K (371.1K-374.8K), 10.8 µs | 4 MB |

### Tier M, against tier A

| Server | a | m | Peak RSS |
|---|---:|---:|---:|
| goose-uring-rest | 592.3K (583.2K-593.9K), 6.7 µs | 491.8K (488.3K-498.2K), 8.1 µs | 13 MB |
| goose-epoll-rest | 433.0K (431.8K-434.6K), 9.2 µs | 365.2K (362.6K-365.8K), 11.0 µs | 8 MB |
