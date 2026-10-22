Requests per second, median (range of runs), and the server's CPU time per request.

### Tier F

| Server | root | id | json | Peak RSS |
|---|---:|---:|---:|---:|
| goose-uring-bare | 482.1K (453.6K-486.9K), 8.3 µs | 468.8K (462.2K-472.4K), 8.5 µs | 413.7K (391.6K-414.1K), 9.6 µs | 10 MB |
| goose-epoll-bare | 382.3K (362.9K-386.4K), 10.5 µs | 380.7K (367.9K-381.8K), 10.5 µs | 325.6K (308.6K-327.0K), 12.3 µs | 4 MB |
| goose-uring-rest | 473.7K (452.7K-487.1K), 8.4 µs | 466.4K (457.1K-472.2K), 8.6 µs | 411.6K (385.7K-412.1K), 9.7 µs | 10 MB |
| goose-epoll-rest | 381.2K (377.9K-382.1K), 10.5 µs | 373.1K (370.0K-374.6K), 10.7 µs | 319.0K (317.3K-324.1K), 12.6 µs | 4 MB |

### Tier R

| Server | routes | Peak RSS |
|---|---:|---:|
| goose-uring-rest | 321.1K (294.0K-323.7K), 12.4 µs | 10 MB |
| goose-epoll-rest | 254.8K (254.0K-257.1K), 15.8 µs | 4 MB |
| goose-uring-rest-gen | 452.8K (452.3K-457.2K), 8.8 µs | 10 MB |
| goose-epoll-rest-gen | 361.4K (358.1K-364.2K), 11.1 µs | 4 MB |

### Tier M, against tier A

| Server | a | m | Peak RSS |
|---|---:|---:|---:|
| goose-uring-rest | 550.6K (549.2K-554.8K), 7.2 µs | 481.1K (478.4K-486.4K), 8.3 µs | 13 MB |
| goose-epoll-rest | 393.4K (391.8K-401.8K), 10.2 µs | 349.4K (345.2K-354.8K), 11.5 µs | 8 MB |
