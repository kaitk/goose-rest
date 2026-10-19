## Saturation

| Server | Tier | JSON | req/s, median | range | p50 ms | p99 ms | CPU µs/req | peak RSS MB | errors |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|
| ntex | A | serialize | 335.1K | 331.8K-335.4K | 0.76 | 1.19 | 11.9 | 42 | 0 |
| ntex | A | template | 355.1K | 349.8K-357.2K | 0.72 | 1.12 | 11.3 | 60 | 0 |
| ntex | B | serialize | 174.2K | 170.9K-176.5K | 1.39 | 2.65 | 23.0 | 86 | 0 |
| ntex | B | template | 228.7K | 228.0K-234.2K | 1.08 | 1.84 | 17.5 | 98 | 0 |
| ntex | C | serialize | 32.9K | 32.2K-33.3K | 7.35 | 18.2 | 121.5 | 208 | 0 |
| ntex | C | template | 107.6K | 106.2K-107.8K | 2.27 | 4.57 | 36.8 | 316 | 0 |

