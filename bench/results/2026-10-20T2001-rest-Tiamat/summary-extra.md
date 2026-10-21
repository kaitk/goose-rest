Requests per second, median (range of runs), and the server's CPU time per request.

### Tier R

| Server | routes | Peak RSS |
|---|---:|---:|
| goose-uring-rest | 316.5K (315.2K-321.3K), 12.6 µs | 10 MB |
| goose-uring-rest-short | 318.7K (316.3K-331.3K), 12.5 µs | 10 MB |
| goose-uring-rest-gen | 437.6K (433.6K-449.7K), 9.1 µs | 11 MB |

### Tier M, against tier A

| Server | a | m | Peak RSS |
|---|---:|---:|---:|
| goose-uring-rest | 527.2K (404.3K-549.8K), 7.5 µs | 431.0K (415.8K-477.3K), 9.0 µs | 13 MB |
| goose-uring-rest-short | 532.8K (523.6K-541.2K), 7.5 µs | 463.3K (459.3K-469.5K), 8.6 µs | 13 MB |
