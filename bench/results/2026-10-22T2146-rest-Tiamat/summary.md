## Saturation

| Server | Tier | JSON | req/s, median | range | p50 ms | p99 ms | CPU µs/req | peak RSS MB | errors |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|
| goose-uring | A | serialize | 568.6K | 562.6K-571.0K | 0.40 | 0.66 | 7.0 | 13 | 0 |
| goose-epoll | A | serialize | 407.8K | 402.4K-409.9K | 0.62 | 0.91 | 9.8 | 8 | 0 |
| goose-epoll-rest | A | serialize | 400.6K | 396.3K-404.3K | 0.62 | 0.97 | 10.0 | 8 | 0 |
| goose-uring-rest | A | serialize | 557.6K | 554.8K-558.0K | 0.42 | 0.68 | 7.1 | 13 | 0 |
| goose-uring | A | template | 580.3K | 577.8K-581.9K | 0.39 | 0.63 | 6.8 | 12 | 0 |
| goose-epoll | A | template | 420.6K | 416.4K-424.2K | 0.60 | 0.94 | 9.5 | 8 | 0 |
| goose-epoll-rest | A | template | 411.9K | 396.7K-413.9K | 0.62 | 0.94 | 9.7 | 8 | 0 |
| goose-uring-rest | A | template | 572.4K | 569.1K-574.4K | 0.40 | 0.67 | 6.9 | 12 | 0 |
| goose-uring | B | serialize | 303.0K | 301.3K-304.2K | 0.82 | 1.27 | 13.2 | 30 | 0 |
| goose-epoll | B | serialize | 231.7K | 231.2K-234.1K | 1.12 | 1.52 | 17.3 | 29 | 0 |
| goose-epoll-rest | B | serialize | 235.1K | 234.5K-235.1K | 1.08 | 1.55 | 17.1 | 29 | 0 |
| goose-uring-rest | B | serialize | 306.0K | 303.7K-310.4K | 0.81 | 1.23 | 13.1 | 31 | 0 |
| goose-uring | B | template | 372.4K | 372.2K-373.4K | 0.66 | 1.02 | 10.7 | 50 | 0 |
| goose-epoll | B | template | 282.2K | 279.0K-282.3K | 0.90 | 1.30 | 14.2 | 50 | 0 |
| goose-epoll-rest | B | template | 279.7K | 278.0K-282.1K | 0.91 | 1.27 | 14.3 | 50 | 0 |
| goose-uring-rest | B | template | 369.4K | 369.0K-370.0K | 0.67 | 1.00 | 10.8 | 50 | 0 |
| goose-uring | C | serialize | 62.0K | 61.6K-62.3K | 3.98 | 8.81 | 64.4 | 71 | 0 |
| goose-epoll | C | serialize | 60.2K | 60.1K-60.4K | 4.10 | 8.42 | 66.6 | 69 | 0 |
| goose-epoll-rest | C | serialize | 60.8K | 60.7K-61.0K | 4.07 | 8.17 | 66.0 | 69 | 0 |
| goose-uring-rest | C | serialize | 62.4K | 62.1K-62.4K | 3.98 | 8.72 | 64.1 | 71 | 0 |
| goose-uring | C | template | 147.2K | 146.3K-147.7K | 1.66 | 3.17 | 27.0 | 58 | 0 |
| goose-epoll | C | template | 137.2K | 135.3K-138.3K | 1.80 | 3.24 | 29.2 | 58 | 0 |
| goose-epoll-rest | C | template | 137.2K | 136.1K-137.5K | 1.80 | 3.15 | 29.2 | 58 | 0 |
| goose-uring-rest | C | template | 145.3K | 145.1K-147.0K | 1.68 | 3.22 | 27.4 | 58 | 0 |

## Tier D

| Server | Run | uploads/s | uploads p50 ms | forms role req/s | forms p99 ms | peak RSS MB | upload errors |
|---|---|---:|---:|---:|---:|---:|---:|
| goose-uring | alone | 1.1K | 16.4-17.1 |  |  | 71 | 0 |
| goose-epoll | alone | 1.1K | 15.3-15.9 |  |  | 69 | 0 |
| goose-epoll-rest | alone | 1.1K | 15.1-17.0 |  |  | 69 | 0 |
| goose-uring-rest | alone | 1.1K | 16.3-17.2 |  |  | 71 | 0 |
| goose-uring | beside forms | 166-169 | 113-141 | 7.6K-7.7K | 67.5-69.0 | 126 | 0 |
| goose-epoll | beside forms | 120-123 | 163-173 | 7.8K | 80.3-87.4 | 133 | 0 |
| goose-epoll-rest | beside forms | 102-121 | 156-191 | 6.8K-7.4K | 87.9-98.0 | 149 | 0 |
| goose-uring-rest | beside forms | 152-162 | 119-141 | 7.0K-7.1K | 71.3-81.8 | 124 | 0 |

## Fixed rate

| Server | Tier | Run | Route | rate reached | p50 ms | p99 ms | errors |
|---|---|---|---|---:|---:|---:|---:|
| goose-uring | A | serialize | item | 77.8K-77.9K of 78.0K | 0.10 | 0.17-0.18 | 0 |
| goose-uring | A | serialize | me | 16.0K of 16.0K | 0.09-0.10 | 0.16-0.17 | 0 |
| goose-uring | A | serialize | write | 6.0K of 6.0K | 0.11 | 0.16-0.18 | 0 |
| goose-epoll | A | serialize | item | 77.7K-77.8K of 78.0K | 0.10 | 0.17-0.20 | 0 |
| goose-epoll | A | serialize | me | 16.0K of 16.0K | 0.09-0.10 | 0.17-0.18 | 0 |
| goose-epoll | A | serialize | write | 6.0K of 6.0K | 0.11-0.12 | 0.17-0.20 | 0 |
| goose-epoll-rest | A | serialize | item | 77.8K of 78.0K | 0.10 | 0.17-0.18 | 0 |
| goose-epoll-rest | A | serialize | me | 16.0K of 16.0K | 0.10 | 0.17 | 0 |
| goose-epoll-rest | A | serialize | write | 6.0K of 6.0K | 0.11 | 0.17 | 0 |
| goose-uring-rest | A | serialize | item | 77.8K-77.9K of 78.0K | 0.10 | 0.17 | 0 |
| goose-uring-rest | A | serialize | me | 16.0K of 16.0K | 0.09-0.10 | 0.17 | 0 |
| goose-uring-rest | A | serialize | write | 6.0K of 6.0K | 0.11 | 0.17 | 0 |
| goose-uring | A | template | item | 77.8K-77.9K of 78.0K | 0.10 | 0.16-0.18 | 0 |
| goose-uring | A | template | me | 16.0K of 16.0K | 0.09-0.10 | 0.16-0.17 | 0 |
| goose-uring | A | template | write | 6.0K of 6.0K | 0.11 | 0.16-0.17 | 0 |
| goose-epoll | A | template | item | 77.8K of 78.0K | 0.10 | 0.17-0.23 | 0 |
| goose-epoll | A | template | me | 16.0K of 16.0K | 0.09-0.10 | 0.17-0.22 | 0 |
| goose-epoll | A | template | write | 6.0K of 6.0K | 0.11 | 0.17-0.21 | 0 |
| goose-epoll-rest | A | template | item | 77.8K of 78.0K | 0.10 | 0.17-0.18 | 0 |
| goose-epoll-rest | A | template | me | 16.0K of 16.0K | 0.09-0.10 | 0.17 | 0 |
| goose-epoll-rest | A | template | write | 6.0K of 6.0K | 0.11 | 0.17-0.18 | 0 |
| goose-uring-rest | A | template | item | 77.8K-77.9K of 78.0K | 0.10 | 0.17-0.18 | 0 |
| goose-uring-rest | A | template | me | 16.0K of 16.0K | 0.09 | 0.17 | 0 |
| goose-uring-rest | A | template | write | 6.0K of 6.0K | 0.11 | 0.17-0.18 | 0 |
| goose-uring | B | serialize | entries | 6.0K of 6.0K | 0.11 | 0.15 | 0 |
| goose-uring | B | serialize | patch | 2.4K of 2.4K | 0.10 | 0.14-0.15 | 0 |
| goose-uring | B | serialize | projects | 3.6K of 3.6K | 0.10 | 0.14-0.15 | 0 |
| goose-uring | B | serialize | session | 6.0K of 6.0K | 0.10 | 0.14-0.15 | 0 |
| goose-uring | B | serialize | timer | 6.0K of 6.0K | 0.10 | 0.14-0.15 | 0 |
| goose-epoll | B | serialize | entries | 6.0K of 6.0K | 0.11 | 0.15-0.16 | 0 |
| goose-epoll | B | serialize | patch | 2.4K of 2.4K | 0.10-0.11 | 0.14-0.15 | 0 |
| goose-epoll | B | serialize | projects | 3.6K of 3.6K | 0.10 | 0.15 | 0 |
| goose-epoll | B | serialize | session | 6.0K of 6.0K | 0.10 | 0.14-0.15 | 0 |
| goose-epoll | B | serialize | timer | 6.0K of 6.0K | 0.10 | 0.14-0.15 | 0 |
| goose-epoll-rest | B | serialize | entries | 6.0K of 6.0K | 0.11 | 0.15 | 0 |
| goose-epoll-rest | B | serialize | patch | 2.4K of 2.4K | 0.10 | 0.14-0.15 | 0 |
| goose-epoll-rest | B | serialize | projects | 3.6K of 3.6K | 0.10 | 0.14-0.15 | 0 |
| goose-epoll-rest | B | serialize | session | 6.0K of 6.0K | 0.10 | 0.14-0.15 | 0 |
| goose-epoll-rest | B | serialize | timer | 6.0K of 6.0K | 0.10 | 0.14 | 0 |
| goose-uring-rest | B | serialize | entries | 6.0K of 6.0K | 0.11 | 0.15 | 0 |
| goose-uring-rest | B | serialize | patch | 2.4K of 2.4K | 0.10 | 0.14-0.15 | 0 |
| goose-uring-rest | B | serialize | projects | 3.6K of 3.6K | 0.10 | 0.14-0.15 | 0 |
| goose-uring-rest | B | serialize | session | 6.0K of 6.0K | 0.10 | 0.14-0.15 | 0 |
| goose-uring-rest | B | serialize | timer | 6.0K of 6.0K | 0.10 | 0.14-0.15 | 0 |
| goose-uring | B | template | entries | 6.0K of 6.0K | 0.10 | 0.14-0.15 | 0 |
| goose-uring | B | template | patch | 2.4K of 2.4K | 0.10 | 0.14-0.15 | 0 |
| goose-uring | B | template | projects | 3.6K of 3.6K | 0.10 | 0.14-0.15 | 0 |
| goose-uring | B | template | session | 6.0K of 6.0K | 0.10 | 0.14-0.15 | 0 |
| goose-uring | B | template | timer | 6.0K of 6.0K | 0.10 | 0.14-0.15 | 0 |
| goose-epoll | B | template | entries | 6.0K of 6.0K | 0.10 | 0.15 | 0 |
| goose-epoll | B | template | patch | 2.4K of 2.4K | 0.10 | 0.14-0.15 | 0 |
| goose-epoll | B | template | projects | 3.6K of 3.6K | 0.10 | 0.14-0.15 | 0 |
| goose-epoll | B | template | session | 6.0K of 6.0K | 0.10 | 0.14-0.15 | 0 |
| goose-epoll | B | template | timer | 6.0K of 6.0K | 0.10 | 0.14 | 0 |
| goose-epoll-rest | B | template | entries | 6.0K of 6.0K | 0.10 | 0.14-0.15 | 0 |
| goose-epoll-rest | B | template | patch | 2.4K of 2.4K | 0.10 | 0.14 | 0 |
| goose-epoll-rest | B | template | projects | 3.6K of 3.6K | 0.10 | 0.14 | 0 |
| goose-epoll-rest | B | template | session | 6.0K of 6.0K | 0.10 | 0.14 | 0 |
| goose-epoll-rest | B | template | timer | 6.0K of 6.0K | 0.10 | 0.14 | 0 |
| goose-uring-rest | B | template | entries | 6.0K of 6.0K | 0.10 | 0.15 | 0 |
| goose-uring-rest | B | template | patch | 2.4K of 2.4K | 0.10 | 0.14-0.15 | 0 |
| goose-uring-rest | B | template | projects | 3.6K of 3.6K | 0.10 | 0.14 | 0 |
| goose-uring-rest | B | template | session | 6.0K of 6.0K | 0.10 | 0.14 | 0 |
| goose-uring-rest | B | template | timer | 6.0K of 6.0K | 0.10 | 0.14-0.15 | 0 |
| goose-uring | C | serialize | bookings | 153 of 153 | 0.67-0.69 | 0.86-0.91 | 0 |
| goose-uring | C | serialize | client | 51 of 51 | 0.10-0.11 | 0.14-0.16 | 0 |
| goose-uring | C | serialize | encounter | 204 of 204 | 0.12-0.13 | 0.28-0.52 | 0 |
| goose-uring | C | serialize | history | 204 of 204 | 0.14 | 0.21-0.52 | 0 |
| goose-uring | C | serialize | poll | 932-933 of 935 | 0.10-0.11 | 0.44-0.51 | 0 |
| goose-uring | C | serialize | shifts | 153 of 153 | 0.12-0.13 | 0.16-0.18 | 0 |
| goose-epoll | C | serialize | bookings | 153 of 153 | 0.67-0.70 | 0.87-0.88 | 0 |
| goose-epoll | C | serialize | client | 51 of 51 | 0.11 | 0.15-0.16 | 0 |
| goose-epoll | C | serialize | encounter | 204 of 204 | 0.12 | 0.17-0.35 | 0 |
| goose-epoll | C | serialize | history | 204 of 204 | 0.14-0.15 | 0.21-0.46 | 0 |
| goose-epoll | C | serialize | poll | 933-934 of 935 | 0.10 | 0.48-0.51 | 0 |
| goose-epoll | C | serialize | shifts | 153 of 153 | 0.12 | 0.16-0.17 | 0 |
| goose-epoll-rest | C | serialize | bookings | 153 of 153 | 0.66-0.68 | 0.84-0.89 | 0 |
| goose-epoll-rest | C | serialize | client | 51 of 51 | 0.11 | 0.14-0.16 | 0 |
| goose-epoll-rest | C | serialize | encounter | 204 of 204 | 0.12 | 0.17-0.30 | 0 |
| goose-epoll-rest | C | serialize | history | 204 of 204 | 0.14 | 0.21-0.31 | 0 |
| goose-epoll-rest | C | serialize | poll | 933-934 of 935 | 0.10 | 0.42-0.49 | 0 |
| goose-epoll-rest | C | serialize | shifts | 153 of 153 | 0.12 | 0.16-0.17 | 0 |
| goose-uring-rest | C | serialize | bookings | 153 of 153 | 0.67-0.69 | 0.84-0.86 | 0 |
| goose-uring-rest | C | serialize | client | 51 of 51 | 0.11-0.12 | 0.15-0.16 | 0 |
| goose-uring-rest | C | serialize | encounter | 204 of 204 | 0.12-0.13 | 0.17-0.45 | 0 |
| goose-uring-rest | C | serialize | history | 204 of 204 | 0.14-0.15 | 0.25-0.49 | 0 |
| goose-uring-rest | C | serialize | poll | 933 of 935 | 0.11 | 0.49-0.51 | 0 |
| goose-uring-rest | C | serialize | shifts | 153 of 153 | 0.12 | 0.16-0.17 | 0 |
| goose-uring | C | template | bookings | 153 of 153 | 0.29-0.30 | 0.42-0.44 | 0 |
| goose-uring | C | template | client | 51 of 51 | 0.11 | 0.16 | 0 |
| goose-uring | C | template | encounter | 204 of 204 | 0.12 | 0.17-0.30 | 0 |
| goose-uring | C | template | history | 204 of 204 | 0.13 | 0.18 | 0 |
| goose-uring | C | template | poll | 933-935 of 935 | 0.10-0.11 | 0.17-0.18 | 0 |
| goose-uring | C | template | shifts | 153 of 153 | 0.10-0.11 | 0.15-0.16 | 0 |
| goose-epoll | C | template | bookings | 153 of 153 | 0.28-0.29 | 0.43-0.45 | 0 |
| goose-epoll | C | template | client | 51 of 51 | 0.11 | 0.14-0.16 | 0 |
| goose-epoll | C | template | encounter | 204 of 204 | 0.12 | 0.17 | 0 |
| goose-epoll | C | template | history | 204 of 204 | 0.13 | 0.18-0.23 | 0 |
| goose-epoll | C | template | poll | 933-934 of 935 | 0.10 | 0.17-0.19 | 0 |
| goose-epoll | C | template | shifts | 153 of 153 | 0.11 | 0.15 | 0 |
| goose-epoll-rest | C | template | bookings | 153 of 153 | 0.29 | 0.41-0.47 | 0 |
| goose-epoll-rest | C | template | client | 51 of 51 | 0.11-0.12 | 0.15-0.16 | 0 |
| goose-epoll-rest | C | template | encounter | 204 of 204 | 0.12 | 0.17-0.20 | 0 |
| goose-epoll-rest | C | template | history | 204 of 204 | 0.13-0.14 | 0.19-0.23 | 0 |
| goose-epoll-rest | C | template | poll | 933-934 of 935 | 0.10-0.12 | 0.17-0.19 | 0 |
| goose-epoll-rest | C | template | shifts | 153 of 153 | 0.11-0.12 | 0.15-0.17 | 0 |
| goose-uring-rest | C | template | bookings | 153 of 153 | 0.29-0.30 | 0.43-0.45 | 0 |
| goose-uring-rest | C | template | client | 51 of 51 | 0.11-0.12 | 0.15-0.16 | 0 |
| goose-uring-rest | C | template | encounter | 204 of 204 | 0.12-0.13 | 0.17-0.19 | 0 |
| goose-uring-rest | C | template | history | 204 of 204 | 0.13-0.14 | 0.18-0.19 | 0 |
| goose-uring-rest | C | template | poll | 933-934 of 935 | 0.10-0.11 | 0.18-0.19 | 0 |
| goose-uring-rest | C | template | shifts | 153 of 153 | 0.11 | 0.15-0.16 | 0 |

| Server | Tier | Run | CPU µs/req | uploads/s |
|---|---|---|---:|---:|
| goose-uring | A | serialize | 21.0-21.5 |  |
| goose-epoll | A | serialize | 21.3-22.4 |  |
| goose-epoll-rest | A | serialize | 21.1-22.1 |  |
| goose-uring-rest | A | serialize | 21.2-21.9 |  |
| goose-uring | A | template | 21.1-21.2 |  |
| goose-epoll | A | template | 20.6-21.7 |  |
| goose-epoll-rest | A | template | 21.2-21.7 |  |
| goose-uring-rest | A | template | 20.5-22.0 |  |
| goose-uring | B | serialize | 32.9-33.1 |  |
| goose-epoll | B | serialize | 32.4-33.6 |  |
| goose-epoll-rest | B | serialize | 32.6-32.9 |  |
| goose-uring-rest | B | serialize | 32.9-33.4 |  |
| goose-uring | B | template | 31.3-32.2 |  |
| goose-epoll | B | template | 30.5-31.4 |  |
| goose-epoll-rest | B | template | 31.2-31.5 |  |
| goose-uring-rest | B | template | 31.8-32.2 |  |
| goose-uring | C | serialize | 92.2-94.2 |  |
| goose-epoll | C | serialize | 91.8-92.2 |  |
| goose-epoll-rest | C | serialize | 91.8-92.6 |  |
| goose-uring-rest | C | serialize | 93.0-94.2 |  |
| goose-uring | C | template | 54.5-55.3 |  |
| goose-epoll | C | template | 53.7-53.8 |  |
| goose-epoll-rest | C | template | 54.2-57.3 |  |
| goose-uring-rest | C | template | 55.3-57.3 |  |

## Mixed run: tier C's reads, alone and beside uploads

| Server | Tier | Run | Route | rate reached | p50 ms | p99 ms | errors |
|---|---|---|---|---:|---:|---:|---:|
| goose-uring | C | alone | bookings | 153 of 153 | 0.68-0.70 | 0.86-0.91 | 0 |
| goose-uring | C | alone | client | 51 of 51 | 0.11-0.12 | 0.15-0.17 | 0 |
| goose-uring | C | alone | encounter | 204 of 204 | 0.12-0.13 | 0.17-0.54 | 0 |
| goose-uring | C | alone | history | 204 of 204 | 0.14-0.16 | 0.41-0.64 | 0 |
| goose-uring | C | alone | poll | 933-934 of 935 | 0.10-0.12 | 0.49-0.54 | 0 |
| goose-uring | C | alone | shifts | 153 of 153 | 0.12-0.13 | 0.16-0.18 | 0 |
| goose-epoll | C | alone | bookings | 153 of 153 | 0.69 | 0.86-0.89 | 0 |
| goose-epoll | C | alone | client | 51 of 51 | 0.11-0.12 | 0.15-0.17 | 0 |
| goose-epoll | C | alone | encounter | 204 of 204 | 0.12 | 0.17-0.58 | 0 |
| goose-epoll | C | alone | history | 204 of 204 | 0.14-0.15 | 0.21-0.46 | 0 |
| goose-epoll | C | alone | poll | 934 of 935 | 0.10 | 0.48-0.51 | 0 |
| goose-epoll | C | alone | shifts | 153 of 153 | 0.12 | 0.16-0.17 | 0 |
| goose-epoll-rest | C | alone | bookings | 153 of 153 | 0.68-0.69 | 0.84-0.86 | 0 |
| goose-epoll-rest | C | alone | client | 51 of 51 | 0.11 | 0.15 | 0 |
| goose-epoll-rest | C | alone | encounter | 204 of 204 | 0.12 | 0.18-0.67 | 0 |
| goose-epoll-rest | C | alone | history | 204 of 204 | 0.14-0.15 | 0.20-0.66 | 0 |
| goose-epoll-rest | C | alone | poll | 934-935 of 935 | 0.10 | 0.47-0.49 | 0 |
| goose-epoll-rest | C | alone | shifts | 153 of 153 | 0.12 | 0.16-0.17 | 0 |
| goose-uring-rest | C | alone | bookings | 153 of 153 | 0.68-0.69 | 0.86-0.87 | 0 |
| goose-uring-rest | C | alone | client | 51 of 51 | 0.11-0.12 | 0.15-0.16 | 0 |
| goose-uring-rest | C | alone | encounter | 204 of 204 | 0.12-0.13 | 0.19-0.72 | 0 |
| goose-uring-rest | C | alone | history | 204 of 204 | 0.14-0.15 | 0.27-0.58 | 0 |
| goose-uring-rest | C | alone | poll | 932-934 of 935 | 0.10-0.11 | 0.50-0.54 | 0 |
| goose-uring-rest | C | alone | shifts | 153 of 153 | 0.12 | 0.16-0.17 | 0 |
| goose-uring | C | uploads | bookings | 153 of 153 | 2.11-3.17 | 6.20-7.31 | 0 |
| goose-uring | C | uploads | client | 51 of 51 | 2.04-2.93 | 7.45-8.46 | 0 |
| goose-uring | C | uploads | encounter | 204 of 204 | 2.12-3.37 | 7.23-8.80 | 0 |
| goose-uring | C | uploads | history | 204 of 204 | 1.60-2.22 | 5.48-6.78 | 0 |
| goose-uring | C | uploads | poll | 932-933 of 935 | 2.04-3.01 | 7.58-8.72 | 0 |
| goose-uring | C | uploads | shifts | 153 of 153 | 2.40-2.60 | 7.82-8.35 | 0 |
| goose-epoll | C | uploads | bookings | 153 of 153 | 0.75-0.78 | 1.21-1.36 | 0 |
| goose-epoll | C | uploads | client | 51 of 51 | 0.15-0.16 | 0.39-0.60 | 0 |
| goose-epoll | C | uploads | encounter | 204 of 204 | 0.16-0.18 | 0.74-0.84 | 0 |
| goose-epoll | C | uploads | history | 204 of 204 | 0.18-0.21 | 0.62-0.74 | 0 |
| goose-epoll | C | uploads | poll | 933-935 of 935 | 0.14-0.16 | 0.73-0.83 | 0 |
| goose-epoll | C | uploads | shifts | 153 of 153 | 0.15-0.17 | 0.43-0.61 | 0 |
| goose-epoll-rest | C | uploads | bookings | 153 of 153 | 0.77-0.82 | 1.26-1.36 | 0 |
| goose-epoll-rest | C | uploads | client | 51 of 51 | 0.16-0.17 | 0.46-0.50 | 0 |
| goose-epoll-rest | C | uploads | encounter | 204 of 204 | 0.17-0.18 | 0.52-0.93 | 0 |
| goose-epoll-rest | C | uploads | history | 204 of 204 | 0.21-0.22 | 0.55-0.86 | 0 |
| goose-epoll-rest | C | uploads | poll | 933 of 935 | 0.16-0.17 | 0.78-0.85 | 0 |
| goose-epoll-rest | C | uploads | shifts | 153 of 153 | 0.18 | 0.48-0.63 | 0 |
| goose-uring-rest | C | uploads | bookings | 153 of 153 | 2.50-2.76 | 6.05-6.69 | 0 |
| goose-uring-rest | C | uploads | client | 51 of 51 | 2.17-2.50 | 6.10-8.01 | 0 |
| goose-uring-rest | C | uploads | encounter | 204 of 204 | 2.29-2.46 | 6.32-7.98 | 0 |
| goose-uring-rest | C | uploads | history | 204 of 204 | 1.99-2.13 | 4.98-6.01 | 0 |
| goose-uring-rest | C | uploads | poll | 933-934 of 935 | 2.37-2.54 | 6.92-8.12 | 0 |
| goose-uring-rest | C | uploads | shifts | 153 of 153 | 2.18-2.55 | 7.13-8.13 | 0 |

| Server | Tier | Run | CPU µs/req | uploads/s |
|---|---|---|---:|---:|
| goose-uring | C | alone | 93.0-96.2 |  |
| goose-epoll | C | alone | 91.8-92.6 |  |
| goose-epoll-rest | C | alone | 91.8-93.0 |  |
| goose-uring-rest | C | alone | 93.1-94.2 |  |
| goose-uring | C | uploads | 2248.1-2315.5 | 936-1.1K |
| goose-epoll | C | uploads | 2261.8-2283.5 | 1.1K |
| goose-epoll-rest | C | uploads | 2302.8-2340.5 | 1.1K |
| goose-uring-rest | C | uploads | 2288.9-2311.8 | 1.1K |

