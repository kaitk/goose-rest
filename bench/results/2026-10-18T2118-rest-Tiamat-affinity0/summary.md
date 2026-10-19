## Saturation

| Server | Tier | JSON | req/s, median | range | p50 ms | p99 ms | CPU µs/req | peak RSS MB | errors |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|
| ntex | A | serialize | 333.9K | 329.5K-337.5K | 0.76 | 1.20 | 12.0 | 42 | 0 |
| ntex | A | template | 351.3K | 348.5K-351.9K | 0.73 | 1.13 | 11.4 | 60 | 0 |
| ntex | B | serialize | 176.1K | 175.8K-176.4K | 1.38 | 2.60 | 22.7 | 86 | 0 |
| ntex | B | template | 231.9K | 231.1K-233.3K | 1.07 | 1.81 | 17.3 | 98 | 0 |
| ntex | C | serialize | 33.3K | 33.1K-33.5K | 7.26 | 17.5 | 120.1 | 200 | 0 |
| ntex | C | template | 109.8K | 109.1K-110.2K | 2.22 | 4.45 | 36.0 | 338 | 0 |

