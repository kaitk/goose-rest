## Saturation

| Server | Tier | JSON | req/s, median | range | p50 ms | p99 ms | CPU µs/req | peak RSS MB | errors |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|
| goose-uring | A | serialize | 587.9K | 573.3K-591.8K | 0.37 | 0.67 | 6.7 | 13 | 0 |
| goose-epoll | A | serialize | 437.9K | 436.5K-444.5K | 0.56 | 0.89 | 9.1 | 8 | 0 |
| goose-epoll-rest | A | serialize | 427.4K | 427.3K-429.8K | 0.58 | 0.95 | 9.4 | 8 | 0 |
| goose-uring-rest | A | serialize | 583.1K | 579.8K-584.1K | 0.38 | 0.65 | 6.8 | 13 | 0 |
| goose-uring | A | template | 601.0K | 601.0K-601.6K | 0.35 | 0.60 | 6.5 | 12 | 0 |
| goose-epoll | A | template | 455.0K | 454.5K-457.4K | 0.54 | 0.90 | 8.8 | 8 | 0 |
| goose-epoll-rest | A | template | 442.1K | 442.0K-445.3K | 0.56 | 0.92 | 9.0 | 8 | 0 |
| goose-uring-rest | A | template | 592.6K | 592.5K-593.4K | 0.36 | 0.64 | 6.7 | 12 | 0 |
| goose-uring | B | serialize | 315.4K | 311.2K-319.2K | 0.78 | 1.22 | 12.7 | 30 | 0 |
| goose-epoll | B | serialize | 244.6K | 244.3K-245.6K | 1.07 | 1.45 | 16.4 | 29 | 0 |
| goose-epoll-rest | B | serialize | 243.1K | 242.6K-244.8K | 1.05 | 1.54 | 16.5 | 29 | 0 |
| goose-uring-rest | B | serialize | 316.5K | 316.3K-317.7K | 0.78 | 1.20 | 12.6 | 31 | 0 |
| goose-uring | B | template | 391.3K | 385.7K-394.3K | 0.63 | 0.96 | 10.2 | 50 | 0 |
| goose-epoll | B | template | 296.6K | 294.6K-298.3K | 0.85 | 1.28 | 13.5 | 50 | 0 |
| goose-epoll-rest | B | template | 292.3K | 290.1K-292.7K | 0.87 | 1.28 | 13.7 | 50 | 0 |
| goose-uring-rest | B | template | 390.7K | 387.1K-395.4K | 0.63 | 0.99 | 10.2 | 50 | 0 |
| goose-uring | C | serialize | 63.3K | 62.0K-63.3K | 3.93 | 8.59 | 63.2 | 71 | 0 |
| goose-epoll | C | serialize | 61.7K | 61.5K-62.0K | 4.02 | 8.15 | 65.0 | 69 | 0 |
| goose-epoll-rest | C | serialize | 61.3K | 61.1K-61.7K | 4.05 | 8.08 | 65.3 | 69 | 0 |
| goose-uring-rest | C | serialize | 63.2K | 63.1K-63.7K | 3.93 | 8.49 | 63.3 | 71 | 0 |
| goose-uring | C | template | 156.3K | 155.8K-158.8K | 1.55 | 3.00 | 25.4 | 58 | 0 |
| goose-epoll | C | template | 148.1K | 144.4K-148.7K | 1.66 | 2.85 | 27.0 | 58 | 0 |
| goose-epoll-rest | C | template | 144.3K | 143.8K-146.1K | 1.71 | 2.91 | 27.7 | 58 | 0 |
| goose-uring-rest | C | template | 155.3K | 154.2K-155.7K | 1.56 | 3.07 | 25.6 | 58 | 0 |

## Tier D

| Server | Run | uploads/s | uploads p50 ms | forms role req/s | forms p99 ms | peak RSS MB | upload errors |
|---|---|---:|---:|---:|---:|---:|---:|
| goose-uring | alone | 1.1K-1.2K | 16.4-16.6 |  |  | 71 | 0 |
| goose-epoll | alone | 1.1K-1.2K | 14.7-16.2 |  |  | 69 | 0 |
| goose-epoll-rest | alone | 1.1K | 15.0-16.9 |  |  | 70 | 0 |
| goose-uring-rest | alone | 1.1K | 16.4-17.1 |  |  | 71 | 0 |
| goose-uring | beside forms | 170-175 | 117-118 | 7.7K-7.8K | 64.7-67.1 | 125 | 0 |
| goose-epoll | beside forms | 123-125 | 148-160 | 7.7K-8.0K | 79.9-86.0 | 132 | 0 |
| goose-epoll-rest | beside forms | 108-116 | 153-204 | 7.2K-7.3K | 86.4-92.2 | 149 | 0 |
| goose-uring-rest | beside forms | 150-156 | 123-134 | 6.7K-6.9K | 74.3-78.3 | 123 | 0 |

## Fixed rate

| Server | Tier | Run | Route | rate reached | p50 ms | p99 ms | errors |
|---|---|---|---|---:|---:|---:|---:|
| goose-uring | A | serialize | item | 77.8K-77.9K of 78.0K | 0.10 | 0.17-0.19 | 0 |
| goose-uring | A | serialize | me | 16.0K of 16.0K | 0.10 | 0.17-0.18 | 0 |
| goose-uring | A | serialize | write | 6.0K of 6.0K | 0.11 | 0.17-0.19 | 0 |
| goose-epoll | A | serialize | item | 77.8K-77.9K of 78.0K | 0.10 | 0.16-0.18 | 0 |
| goose-epoll | A | serialize | me | 16.0K of 16.0K | 0.09-0.10 | 0.16-0.18 | 0 |
| goose-epoll | A | serialize | write | 6.0K of 6.0K | 0.11 | 0.17-0.18 | 0 |
| goose-epoll-rest | A | serialize | item | 77.8K-77.9K of 78.0K | 0.10 | 0.17-0.20 | 0 |
| goose-epoll-rest | A | serialize | me | 16.0K of 16.0K | 0.09 | 0.16-0.19 | 0 |
| goose-epoll-rest | A | serialize | write | 6.0K of 6.0K | 0.11 | 0.17-0.19 | 0 |
| goose-uring-rest | A | serialize | item | 77.8K of 78.0K | 0.10 | 0.17-0.20 | 0 |
| goose-uring-rest | A | serialize | me | 16.0K of 16.0K | 0.09-0.10 | 0.16-0.19 | 0 |
| goose-uring-rest | A | serialize | write | 6.0K of 6.0K | 0.11 | 0.17-0.20 | 0 |
| goose-uring | A | template | item | 77.8K of 78.0K | 0.10 | 0.17-0.18 | 0 |
| goose-uring | A | template | me | 16.0K of 16.0K | 0.09-0.10 | 0.16-0.17 | 0 |
| goose-uring | A | template | write | 6.0K of 6.0K | 0.11 | 0.17-0.19 | 0 |
| goose-epoll | A | template | item | 77.7K-77.8K of 78.0K | 0.10-0.11 | 0.19-1.16 | 0 |
| goose-epoll | A | template | me | 16.0K of 16.0K | 0.09-0.10 | 0.18-1.28 | 0 |
| goose-epoll | A | template | write | 6.0K of 6.0K | 0.11-0.12 | 0.18-1.17 | 0 |
| goose-epoll-rest | A | template | item | 77.8K of 78.0K | 0.10 | 0.17-0.19 | 0 |
| goose-epoll-rest | A | template | me | 16.0K of 16.0K | 0.09-0.10 | 0.16-0.18 | 0 |
| goose-epoll-rest | A | template | write | 6.0K of 6.0K | 0.11 | 0.17-0.18 | 0 |
| goose-uring-rest | A | template | item | 77.7K-77.9K of 78.0K | 0.10 | 0.17-0.20 | 0 |
| goose-uring-rest | A | template | me | 16.0K of 16.0K | 0.09-0.10 | 0.17-0.18 | 0 |
| goose-uring-rest | A | template | write | 6.0K of 6.0K | 0.11 | 0.18-0.19 | 0 |
| goose-uring | B | serialize | entries | 6.0K of 6.0K | 0.10-0.11 | 0.15-0.17 | 0 |
| goose-uring | B | serialize | patch | 2.4K of 2.4K | 0.10 | 0.15-0.16 | 0 |
| goose-uring | B | serialize | projects | 3.6K of 3.6K | 0.10 | 0.14-0.15 | 0 |
| goose-uring | B | serialize | session | 6.0K of 6.0K | 0.10 | 0.14-0.15 | 0 |
| goose-uring | B | serialize | timer | 6.0K of 6.0K | 0.10 | 0.14-0.16 | 0 |
| goose-epoll | B | serialize | entries | 6.0K of 6.0K | 0.10-0.11 | 0.16-0.18 | 0 |
| goose-epoll | B | serialize | patch | 2.4K of 2.4K | 0.10 | 0.15-0.16 | 0 |
| goose-epoll | B | serialize | projects | 3.6K of 3.6K | 0.10 | 0.14-0.15 | 0 |
| goose-epoll | B | serialize | session | 6.0K of 6.0K | 0.10 | 0.14-0.17 | 0 |
| goose-epoll | B | serialize | timer | 6.0K of 6.0K | 0.09-0.10 | 0.14-0.15 | 0 |
| goose-epoll-rest | B | serialize | entries | 6.0K of 6.0K | 0.10-0.11 | 0.16 | 0 |
| goose-epoll-rest | B | serialize | patch | 2.4K of 2.4K | 0.10 | 0.14-0.15 | 0 |
| goose-epoll-rest | B | serialize | projects | 3.6K of 3.6K | 0.10 | 0.14-0.15 | 0 |
| goose-epoll-rest | B | serialize | session | 6.0K of 6.0K | 0.10 | 0.14-0.15 | 0 |
| goose-epoll-rest | B | serialize | timer | 6.0K of 6.0K | 0.10 | 0.14-0.15 | 0 |
| goose-uring-rest | B | serialize | entries | 6.0K of 6.0K | 0.10-0.11 | 0.15-0.17 | 0 |
| goose-uring-rest | B | serialize | patch | 2.4K of 2.4K | 0.10 | 0.15-0.16 | 0 |
| goose-uring-rest | B | serialize | projects | 3.6K of 3.6K | 0.10 | 0.14-0.16 | 0 |
| goose-uring-rest | B | serialize | session | 6.0K of 6.0K | 0.10 | 0.14-0.16 | 0 |
| goose-uring-rest | B | serialize | timer | 6.0K of 6.0K | 0.10 | 0.14-0.16 | 0 |
| goose-uring | B | template | entries | 6.0K of 6.0K | 0.10 | 0.15-0.16 | 0 |
| goose-uring | B | template | patch | 2.4K of 2.4K | 0.10 | 0.14-0.16 | 0 |
| goose-uring | B | template | projects | 3.6K of 3.6K | 0.10 | 0.14-0.15 | 0 |
| goose-uring | B | template | session | 6.0K of 6.0K | 0.10 | 0.14-0.15 | 0 |
| goose-uring | B | template | timer | 6.0K of 6.0K | 0.10 | 0.14-0.15 | 0 |
| goose-epoll | B | template | entries | 6.0K of 6.0K | 0.10 | 0.16 | 0 |
| goose-epoll | B | template | patch | 2.4K of 2.4K | 0.10 | 0.15 | 0 |
| goose-epoll | B | template | projects | 3.6K of 3.6K | 0.10 | 0.14-0.15 | 0 |
| goose-epoll | B | template | session | 6.0K of 6.0K | 0.09-0.10 | 0.14-0.15 | 0 |
| goose-epoll | B | template | timer | 6.0K of 6.0K | 0.10 | 0.15 | 0 |
| goose-epoll-rest | B | template | entries | 6.0K of 6.0K | 0.10 | 0.15-0.16 | 0 |
| goose-epoll-rest | B | template | patch | 2.4K of 2.4K | 0.10 | 0.14-0.15 | 0 |
| goose-epoll-rest | B | template | projects | 3.6K of 3.6K | 0.10 | 0.14-0.15 | 0 |
| goose-epoll-rest | B | template | session | 6.0K of 6.0K | 0.10 | 0.14-0.15 | 0 |
| goose-epoll-rest | B | template | timer | 6.0K of 6.0K | 0.10 | 0.14-0.15 | 0 |
| goose-uring-rest | B | template | entries | 6.0K of 6.0K | 0.10-0.11 | 0.15-0.16 | 0 |
| goose-uring-rest | B | template | patch | 2.4K of 2.4K | 0.10 | 0.15 | 0 |
| goose-uring-rest | B | template | projects | 3.6K of 3.6K | 0.10 | 0.15 | 0 |
| goose-uring-rest | B | template | session | 6.0K of 6.0K | 0.10 | 0.15 | 0 |
| goose-uring-rest | B | template | timer | 6.0K of 6.0K | 0.10 | 0.15 | 0 |
| goose-uring | C | serialize | bookings | 153 of 153 | 0.68-0.69 | 0.87-0.91 | 0 |
| goose-uring | C | serialize | client | 51 of 51 | 0.11-0.12 | 0.15-0.64 | 0 |
| goose-uring | C | serialize | encounter | 204 of 204 | 0.12 | 0.18-0.64 | 0 |
| goose-uring | C | serialize | history | 204 of 204 | 0.14 | 0.20-0.66 | 0 |
| goose-uring | C | serialize | poll | 933-935 of 935 | 0.10-0.11 | 0.48-0.51 | 0 |
| goose-uring | C | serialize | shifts | 153 of 153 | 0.11-0.12 | 0.16-0.20 | 0 |
| goose-epoll | C | serialize | bookings | 153 of 153 | 0.67-0.68 | 0.86-0.91 | 0 |
| goose-epoll | C | serialize | client | 51 of 51 | 0.11 | 0.15-0.17 | 0 |
| goose-epoll | C | serialize | encounter | 204 of 204 | 0.12-0.13 | 0.17-0.54 | 0 |
| goose-epoll | C | serialize | history | 204 of 204 | 0.14-0.15 | 0.20-0.63 | 0 |
| goose-epoll | C | serialize | poll | 933-934 of 935 | 0.10-0.11 | 0.47-0.50 | 0 |
| goose-epoll | C | serialize | shifts | 153 of 153 | 0.12 | 0.16-0.20 | 0 |
| goose-epoll-rest | C | serialize | bookings | 153 of 153 | 0.66-0.67 | 0.86-0.87 | 0 |
| goose-epoll-rest | C | serialize | client | 51 of 51 | 0.11 | 0.15-0.16 | 0 |
| goose-epoll-rest | C | serialize | encounter | 204 of 204 | 0.12 | 0.24-0.62 | 0 |
| goose-epoll-rest | C | serialize | history | 204 of 204 | 0.14-0.15 | 0.21-0.46 | 0 |
| goose-epoll-rest | C | serialize | poll | 934 of 935 | 0.10 | 0.49-0.50 | 0 |
| goose-epoll-rest | C | serialize | shifts | 153 of 153 | 0.12 | 0.16-0.17 | 0 |
| goose-uring-rest | C | serialize | bookings | 153 of 153 | 0.65-0.68 | 0.86-0.91 | 0 |
| goose-uring-rest | C | serialize | client | 51 of 51 | 0.11 | 0.16-0.17 | 0 |
| goose-uring-rest | C | serialize | encounter | 204 of 204 | 0.12 | 0.18-0.19 | 0 |
| goose-uring-rest | C | serialize | history | 204 of 204 | 0.14 | 0.20-0.36 | 0 |
| goose-uring-rest | C | serialize | poll | 933-934 of 935 | 0.10-0.11 | 0.48-0.52 | 0 |
| goose-uring-rest | C | serialize | shifts | 153 of 153 | 0.12 | 0.17 | 0 |
| goose-uring | C | template | bookings | 153 of 153 | 0.28-0.29 | 0.41-0.49 | 0 |
| goose-uring | C | template | client | 51 of 51 | 0.11 | 0.16 | 0 |
| goose-uring | C | template | encounter | 204 of 204 | 0.12 | 0.16-0.25 | 0 |
| goose-uring | C | template | history | 204 of 204 | 0.13 | 0.18-0.25 | 0 |
| goose-uring | C | template | poll | 933-934 of 935 | 0.10 | 0.17-0.21 | 0 |
| goose-uring | C | template | shifts | 153 of 153 | 0.10-0.11 | 0.15-0.17 | 0 |
| goose-epoll | C | template | bookings | 153 of 153 | 0.28-0.29 | 0.43-0.48 | 0 |
| goose-epoll | C | template | client | 51 of 51 | 0.10-0.11 | 0.15-0.16 | 0 |
| goose-epoll | C | template | encounter | 204 of 204 | 0.12 | 0.16-0.21 | 0 |
| goose-epoll | C | template | history | 204 of 204 | 0.13 | 0.19-0.26 | 0 |
| goose-epoll | C | template | poll | 933 of 935 | 0.10 | 0.17-0.20 | 0 |
| goose-epoll | C | template | shifts | 153 of 153 | 0.10-0.12 | 0.15-0.31 | 0 |
| goose-epoll-rest | C | template | bookings | 153 of 153 | 0.28 | 0.42-0.45 | 0 |
| goose-epoll-rest | C | template | client | 51 of 51 | 0.11-0.12 | 0.15-0.23 | 0 |
| goose-epoll-rest | C | template | encounter | 204 of 204 | 0.12 | 0.17-0.28 | 0 |
| goose-epoll-rest | C | template | history | 204 of 204 | 0.13 | 0.18-0.23 | 0 |
| goose-epoll-rest | C | template | poll | 933-934 of 935 | 0.10 | 0.18-0.19 | 0 |
| goose-epoll-rest | C | template | shifts | 153 of 153 | 0.10-0.11 | 0.15-0.17 | 0 |
| goose-uring-rest | C | template | bookings | 153 of 153 | 0.28-0.30 | 0.43-0.47 | 0 |
| goose-uring-rest | C | template | client | 51 of 51 | 0.11 | 0.15-0.16 | 0 |
| goose-uring-rest | C | template | encounter | 204 of 204 | 0.12 | 0.16-0.18 | 0 |
| goose-uring-rest | C | template | history | 204 of 204 | 0.13 | 0.18-0.20 | 0 |
| goose-uring-rest | C | template | poll | 933-934 of 935 | 0.10 | 0.17-0.20 | 0 |
| goose-uring-rest | C | template | shifts | 153 of 153 | 0.11 | 0.16-0.17 | 0 |

| Server | Tier | Run | CPU µs/req | uploads/s |
|---|---|---|---:|---:|
| goose-uring | A | serialize | 20.7-21.2 |  |
| goose-epoll | A | serialize | 21.2-22.0 |  |
| goose-epoll-rest | A | serialize | 20.8-21.3 |  |
| goose-uring-rest | A | serialize | 20.9-21.6 |  |
| goose-uring | A | template | 20.9-21.1 |  |
| goose-epoll | A | template | 20.8-22.7 |  |
| goose-epoll-rest | A | template | 21.5-21.8 |  |
| goose-uring-rest | A | template | 21.4-21.7 |  |
| goose-uring | B | serialize | 32.5-32.7 |  |
| goose-epoll | B | serialize | 31.6-32.7 |  |
| goose-epoll-rest | B | serialize | 32.1-32.4 |  |
| goose-uring-rest | B | serialize | 32.6-32.8 |  |
| goose-uring | B | template | 31.0-31.3 |  |
| goose-epoll | B | template | 30.2-30.6 |  |
| goose-epoll-rest | B | template | 30.6-30.8 |  |
| goose-uring-rest | B | template | 31.2-32.0 |  |
| goose-uring | C | serialize | 91.8-92.6 |  |
| goose-epoll | C | serialize | 90.2-92.2 |  |
| goose-epoll-rest | C | serialize | 91.8-92.2 |  |
| goose-uring-rest | C | serialize | 91.5-93.8 |  |
| goose-uring | C | template | 53.0-54.5 |  |
| goose-epoll | C | template | 52.2-54.2 |  |
| goose-epoll-rest | C | template | 53.4-54.2 |  |
| goose-uring-rest | C | template | 53.8-56.1 |  |

## Mixed run: tier C's reads, alone and beside uploads

| Server | Tier | Run | Route | rate reached | p50 ms | p99 ms | errors |
|---|---|---|---|---:|---:|---:|---:|
| goose-uring | C | alone | bookings | 153 of 153 | 0.66-0.67 | 0.86-0.90 | 0 |
| goose-uring | C | alone | client | 51 of 51 | 0.11 | 0.15-0.17 | 0 |
| goose-uring | C | alone | encounter | 204 of 204 | 0.12 | 0.29-0.41 | 0 |
| goose-uring | C | alone | history | 204 of 204 | 0.14 | 0.24-0.67 | 0 |
| goose-uring | C | alone | poll | 932-934 of 935 | 0.10 | 0.44-0.53 | 0 |
| goose-uring | C | alone | shifts | 153 of 153 | 0.12 | 0.17-0.19 | 0 |
| goose-epoll | C | alone | bookings | 153 of 153 | 0.67 | 0.86-0.89 | 0 |
| goose-epoll | C | alone | client | 51 of 51 | 0.10-0.11 | 0.16 | 0 |
| goose-epoll | C | alone | encounter | 204 of 204 | 0.12 | 0.18-0.33 | 0 |
| goose-epoll | C | alone | history | 204 of 204 | 0.14 | 0.20-0.57 | 0 |
| goose-epoll | C | alone | poll | 933-934 of 935 | 0.10 | 0.42-0.49 | 0 |
| goose-epoll | C | alone | shifts | 153 of 153 | 0.12 | 0.16-0.17 | 0 |
| goose-epoll-rest | C | alone | bookings | 153 of 153 | 0.67-0.68 | 0.86-0.90 | 0 |
| goose-epoll-rest | C | alone | client | 51 of 51 | 0.11 | 0.15-0.17 | 0 |
| goose-epoll-rest | C | alone | encounter | 204 of 204 | 0.12 | 0.18-0.34 | 0 |
| goose-epoll-rest | C | alone | history | 204 of 204 | 0.14 | 0.21-0.56 | 0 |
| goose-epoll-rest | C | alone | poll | 933-934 of 935 | 0.10 | 0.48-0.51 | 0 |
| goose-epoll-rest | C | alone | shifts | 153 of 153 | 0.12 | 0.16-0.17 | 0 |
| goose-uring-rest | C | alone | bookings | 153 of 153 | 0.67-0.69 | 0.85-0.87 | 0 |
| goose-uring-rest | C | alone | client | 51 of 51 | 0.11-0.12 | 0.16-0.17 | 0 |
| goose-uring-rest | C | alone | encounter | 204 of 204 | 0.12-0.13 | 0.18-0.48 | 0 |
| goose-uring-rest | C | alone | history | 204 of 204 | 0.14-0.15 | 0.20-0.67 | 0 |
| goose-uring-rest | C | alone | poll | 933-934 of 935 | 0.10-0.11 | 0.47-0.52 | 0 |
| goose-uring-rest | C | alone | shifts | 153 of 153 | 0.12 | 0.16-0.17 | 0 |
| goose-uring | C | uploads | bookings | 153 of 153 | 2.20-2.66 | 5.43-7.31 | 0 |
| goose-uring | C | uploads | client | 51 of 51 | 1.54-2.07 | 5.95-6.85 | 0 |
| goose-uring | C | uploads | encounter | 204 of 204 | 1.76-2.30 | 5.88-7.87 | 0 |
| goose-uring | C | uploads | history | 204 of 204 | 1.73-1.94 | 4.66-6.54 | 0 |
| goose-uring | C | uploads | poll | 933-934 of 935 | 2.04-2.34 | 6.06-8.10 | 0 |
| goose-uring | C | uploads | shifts | 153 of 153 | 1.83-2.55 | 5.69-8.20 | 0 |
| goose-epoll | C | uploads | bookings | 153 of 153 | 0.74-0.78 | 1.18-1.34 | 0 |
| goose-epoll | C | uploads | client | 51 of 51 | 0.14-0.18 | 0.34-0.59 | 0 |
| goose-epoll | C | uploads | encounter | 204 of 204 | 0.15-0.17 | 0.51-0.81 | 0 |
| goose-epoll | C | uploads | history | 204 of 204 | 0.18-0.21 | 0.77-0.92 | 0 |
| goose-epoll | C | uploads | poll | 933 of 935 | 0.14-0.17 | 0.71-0.83 | 0 |
| goose-epoll | C | uploads | shifts | 153 of 153 | 0.15-0.18 | 0.36-0.62 | 0 |
| goose-epoll-rest | C | uploads | bookings | 153 of 153 | 0.77-0.78 | 1.24-1.28 | 0 |
| goose-epoll-rest | C | uploads | client | 51 of 51 | 0.17-0.18 | 0.40-0.48 | 0 |
| goose-epoll-rest | C | uploads | encounter | 204 of 204 | 0.19-0.20 | 0.55-0.87 | 0 |
| goose-epoll-rest | C | uploads | history | 204 of 204 | 0.22-0.23 | 0.57-0.85 | 0 |
| goose-epoll-rest | C | uploads | poll | 933-934 of 935 | 0.17-0.18 | 0.76-0.79 | 0 |
| goose-epoll-rest | C | uploads | shifts | 153 of 153 | 0.18-0.20 | 0.46-0.65 | 0 |
| goose-uring-rest | C | uploads | bookings | 153 of 153 | 2.65-2.77 | 6.73-7.51 | 0 |
| goose-uring-rest | C | uploads | client | 51 of 51 | 2.54-3.17 | 7.28-8.33 | 0 |
| goose-uring-rest | C | uploads | encounter | 204 of 204 | 2.55-2.80 | 7.57-8.41 | 0 |
| goose-uring-rest | C | uploads | history | 204 of 204 | 2.18-2.37 | 6.33-6.72 | 0 |
| goose-uring-rest | C | uploads | poll | 933-934 of 935 | 2.79-2.92 | 8.37-8.67 | 0 |
| goose-uring-rest | C | uploads | shifts | 153 of 153 | 2.60-2.73 | 8.10-8.48 | 0 |

| Server | Tier | Run | CPU µs/req | uploads/s |
|---|---|---|---:|---:|
| goose-uring | C | alone | 91.4-92.3 |  |
| goose-epoll | C | alone | 90.7-91.8 |  |
| goose-epoll-rest | C | alone | 91.4-92.2 |  |
| goose-uring-rest | C | alone | 91.9-93.8 |  |
| goose-uring | C | uploads | 2251.6-2315.3 | 1.1K |
| goose-epoll | C | uploads | 2243.5-2306.2 | 1.1K |
| goose-epoll-rest | C | uploads | 2340.8-2347.7 | 1.1K |
| goose-uring-rest | C | uploads | 2321.0-2330.3 | 1.1K |

