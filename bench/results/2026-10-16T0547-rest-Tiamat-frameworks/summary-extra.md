Requests per second, median (range of runs), and the server's CPU time per request.

### Tier F

| Server | root | id | json | Peak RSS |
|---|---:|---:|---:|---:|
| axum | 281.7K (281.1K-282.6K), 14.2 µs | 256.0K (251.7K-257.6K), 15.7 µs | 199.7K (197.9K-201.2K), 20.1 µs | 22 MB |
| actix-web | 320.0K (319.2K-321.5K), 12.5 µs | 270.7K (266.4K-276.5K), 14.8 µs | 220.4K (219.8K-221.9K), 18.2 µs | 14 MB |
| dusty-routes | 391.5K (385.8K-392.9K), 10.2 µs | 372.2K (370.0K-373.5K), 10.8 µs | 258.0K (256.0K-281.4K), 15.6 µs | 10 MB |

### Tier R

| Server | routes | Peak RSS |
|---|---:|---:|
| axum | 253.2K (247.4K-256.0K), 15.9 µs | 26 MB |
| actix-web | 145.0K (144.7K-146.6K), 27.7 µs | 30 MB |
| dusty-routes | 360.4K (356.1K-367.2K), 11.1 µs | 9 MB |

### Tier M, against tier A

| Server | a | m | Peak RSS |
|---|---:|---:|---:|
| axum | 243.6K (241.8K-244.6K), 16.4 µs | 183.9K (182.9K-186.8K), 21.8 µs | 28 MB |
| actix-web | 264.7K (259.9K-265.4K), 15.1 µs | 220.5K (213.9K-223.5K), 18.2 µs | 20 MB |
| dusty-routes | 355.0K (354.3K-360.0K), 11.3 µs | 333.7K (328.3K-336.7K), 12.0 µs | 15 MB |
