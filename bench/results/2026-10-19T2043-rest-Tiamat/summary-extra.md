Requests per second, median (range of runs), and the server's CPU time per request.

### Tier F

| Server | root | id | json | Peak RSS |
|---|---:|---:|---:|---:|
| goose-uring-bare | 526.9K (524.4K-532.5K), 7.6 µs | 521.5K (514.0K-526.0K), 7.7 µs | 445.7K (441.7K-447.6K), 9.0 µs | 10 MB |
| goose-epoll-bare | 413.4K (410.5K-415.4K), 9.7 µs | 402.7K (395.6K-406.1K), 9.9 µs | 344.7K (336.6K-345.4K), 11.6 µs | 4 MB |
| goose-uring-rest | 529.7K (522.3K-532.2K), 7.5 µs | 511.2K (506.7K-514.3K), 7.8 µs | 446.9K (438.5K-447.3K), 8.9 µs | 10 MB |
| goose-epoll-rest | 406.5K (402.2K-410.5K), 9.9 µs | 397.4K (396.9K-398.1K), 10.1 µs | 345.1K (336.6K-345.4K), 11.6 µs | 4 MB |
| aegon | 531.5K (526.6K-534.2K), 7.5 µs | 511.6K (500.4K-515.0K), 7.8 µs | 416.3K (415.8K-421.5K), 9.6 µs | 276 MB |
| aegon-small | 531.7K (527.6K-539.4K), 7.5 µs | 509.6K (504.3K-514.4K), 7.9 µs | 420.9K (411.7K-427.4K), 9.5 µs | 20 MB |

### Tier R

| Server | routes | Peak RSS |
|---|---:|---:|
| goose-uring-rest | 334.1K (330.5K-334.6K), 12.0 µs | 10 MB |
| goose-epoll-rest | 263.4K (263.0K-264.1K), 15.2 µs | 4 MB |
| goose-uring-rest-gen | 491.4K (486.9K-492.0K), 8.1 µs | 10 MB |
| goose-epoll-rest-gen | 379.0K (378.8K-380.1K), 10.6 µs | 4 MB |
| aegon | 496.7K (486.3K-505.3K), 8.1 µs | 276 MB |
| aegon-small | 485.3K (463.8K-492.2K), 8.2 µs | 20 MB |

### Tier M, against tier A

| Server | a | m | Peak RSS |
|---|---:|---:|---:|
| goose-uring-rest | 594.3K (558.9K-600.1K), 6.7 µs | 489.2K (447.9K-498.5K), 8.2 µs | 13 MB |
| goose-epoll-rest | 405.5K (384.8K-441.7K), 9.9 µs | 354.3K (350.1K-361.1K), 11.3 µs | 8 MB |
| aegon | 479.3K (477.0K-509.9K), 8.3 µs | 401.9K (400.5K-407.8K), 10.0 µs | 283 MB |
| aegon-small | 522.1K (520.5K-523.0K), 7.7 µs | 403.8K (402.0K-407.1K), 9.9 µs | 27 MB |
