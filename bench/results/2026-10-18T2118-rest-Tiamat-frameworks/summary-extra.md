Requests per second, median (range of runs), and the server's CPU time per request.

### Tier F

| Server | root | id | json | Peak RSS |
|---|---:|---:|---:|---:|
| axum | 293.9K (290.7K-299.1K), 13.7 µs | 266.3K (260.8K-269.9K), 15.1 µs | 209.7K (197.4K-224.0K), 19.1 µs | 25 MB |
| actix-web | 327.6K (323.0K-330.4K), 12.2 µs | 277.9K (277.4K-283.6K), 14.4 µs | 223.3K (219.7K-223.8K), 18.0 µs | 14 MB |
| ntex | 359.7K (357.8K-370.1K), 11.1 µs | 331.1K (330.0K-334.8K), 12.1 µs | 262.6K (261.2K-264.8K), 15.2 µs | 36 MB |
| dusty-routes | 416.0K (410.1K-433.9K), 9.6 µs | 395.4K (380.8K-395.9K), 10.1 µs | 257.7K (255.7K-262.7K), 15.6 µs | 10 MB |

### Tier R

| Server | routes | Peak RSS |
|---|---:|---:|
| axum | 264.3K (260.5K-264.6K), 15.2 µs | 25 MB |
| actix-web | 148.2K (148.1K-149.5K), 27.1 µs | 30 MB |
| ntex | 305.7K (289.7K-308.8K), 13.1 µs | 68 MB |
| dusty-routes | 359.1K (357.9K-371.7K), 11.2 µs | 9 MB |

### Tier M, against tier A

| Server | a | m | Peak RSS |
|---|---:|---:|---:|
| axum | 256.0K (253.2K-258.3K), 15.7 µs | 197.9K (193.8K-198.1K), 20.3 µs | 26 MB |
| actix-web | 276.4K (274.3K-280.5K), 14.5 µs | 227.1K (225.5K-236.9K), 17.6 µs | 20 MB |
| ntex | 333.9K (331.5K-340.2K), 12.0 µs | 284.1K (283.5K-285.8K), 14.1 µs | 48 MB |
| dusty-routes | 365.3K (364.5K-370.3K), 11.0 µs | 343.2K (339.0K-352.0K), 11.7 µs | 15 MB |
