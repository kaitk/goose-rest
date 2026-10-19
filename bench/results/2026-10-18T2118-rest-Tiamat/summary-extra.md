Requests per second, median (range of runs), and the server's CPU time per request.

### Tier F

| Server | root | id | json | Peak RSS |
|---|---:|---:|---:|---:|
| goose-uring-bare | 528.5K (522.1K-530.8K), 7.5 µs | 519.1K (500.8K-520.1K), 7.7 µs | 442.6K (439.9K-444.6K), 9.0 µs | 10 MB |
| goose-epoll-bare | 414.4K (407.5K-415.4K), 9.7 µs | 403.2K (402.2K-406.8K), 9.9 µs | 345.0K (343.1K-350.1K), 11.6 µs | 4 MB |
| goose-uring-rest | 516.7K (491.4K-521.3K), 7.7 µs | 507.9K (500.4K-513.7K), 7.9 µs | 438.7K (437.0K-439.3K), 9.1 µs | 10 MB |
| goose-epoll-rest | 409.9K (408.6K-410.9K), 9.8 µs | 399.7K (399.3K-401.7K), 10.0 µs | 342.6K (336.4K-344.0K), 11.7 µs | 4 MB |

### Tier R

| Server | routes | Peak RSS |
|---|---:|---:|
| goose-uring-rest | 332.7K (328.0K-335.8K), 12.0 µs | 10 MB |
| goose-epoll-rest | 264.7K (263.6K-268.6K), 15.1 µs | 4 MB |
| goose-uring-rest-gen | 475.1K (475.0K-478.7K), 8.4 µs | 11 MB |
| goose-epoll-rest-gen | 376.4K (375.9K-378.4K), 10.7 µs | 4 MB |

### Tier M, against tier A

| Server | a | m | Peak RSS |
|---|---:|---:|---:|
| goose-uring-rest | 593.0K (591.0K-599.3K), 6.7 µs | 504.3K (499.9K-508.6K), 7.9 µs | 13 MB |
| goose-epoll-rest | 453.0K (445.7K-454.5K), 8.8 µs | 365.4K (361.3K-365.8K), 11.0 µs | 8 MB |
