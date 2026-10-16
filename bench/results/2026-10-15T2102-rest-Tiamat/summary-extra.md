Requests per second, median (range of runs), and the server's CPU time per request.

### Tier F

| Server | root | id | json | Peak RSS |
|---|---:|---:|---:|---:|
| goose-uring-bare | 522.6K (521.1K-523.8K), 7.6 µs | 514.1K (511.5K-522.2K), 7.8 µs | 439.6K (436.9K-440.8K), 9.1 µs | 10 MB |
| goose-epoll-bare | 410.2K (407.2K-413.5K), 9.8 µs | 400.6K (397.3K-404.0K), 10.0 µs | 349.0K (345.6K-349.6K), 11.5 µs | 4 MB |
| goose-uring-rest | 523.6K (507.7K-526.0K), 7.6 µs | 507.9K (505.2K-511.0K), 7.8 µs | 440.8K (439.5K-443.6K), 9.1 µs | 10 MB |
| goose-epoll-rest | 406.9K (402.1K-409.1K), 9.8 µs | 389.9K (386.0K-393.7K), 10.3 µs | 341.7K (341.4K-342.2K), 11.7 µs | 4 MB |

### Tier R

| Server | routes | Peak RSS |
|---|---:|---:|
| goose-uring-rest | 333.0K (331.6K-333.6K), 12.0 µs | 10 MB |
| goose-epoll-rest | 264.4K (263.8K-264.9K), 15.2 µs | 4 MB |
| goose-uring-rest-gen | 446.6K (446.2K-451.8K), 8.9 µs | 11 MB |
| goose-epoll-rest-gen | 354.1K (353.4K-354.8K), 11.3 µs | 5 MB |

### Tier M, against tier A

| Server | a | m | Peak RSS |
|---|---:|---:|---:|
| goose-uring-rest | 593.0K (589.1K-596.3K), 6.7 µs | 494.0K (494.0K-496.0K), 8.1 µs | 13 MB |
| goose-epoll-rest | 430.4K (430.4K-442.7K), 9.3 µs | 357.3K (336.0K-365.5K), 11.2 µs | 8 MB |
