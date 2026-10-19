## Saturation

| Server | Tier | JSON | req/s, median | range | p50 ms | p99 ms | CPU µs/req | peak RSS MB | errors |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|
| goose-uring | A | serialize | 607.7K | 605.2K-608.3K | 0.35 | 0.62 | 6.5 | 13 | 0 |
| goose-epoll | A | serialize | 469.2K | 463.3K-470.5K | 0.52 | 0.86 | 8.5 | 8 | 0 |
| goose-epoll-rest | A | serialize | 449.1K | 448.8K-455.2K | 0.54 | 0.97 | 8.9 | 8 | 0 |
| goose-uring-rest | A | serialize | 599.6K | 589.0K-602.4K | 0.36 | 0.64 | 6.6 | 13 | 0 |
| goose-uring | A | template | 615.4K | 614.4K-617.1K | 0.34 | 0.62 | 6.4 | 12 | 0 |
| goose-epoll | A | template | 482.1K | 480.2K-489.1K | 0.51 | 0.80 | 8.3 | 8 | 0 |
| goose-epoll-rest | A | template | 472.5K | 469.2K-474.2K | 0.51 | 0.87 | 8.5 | 8 | 0 |
| goose-uring-rest | A | template | 607.9K | 595.0K-613.1K | 0.35 | 0.65 | 6.5 | 12 | 0 |
| goose-uring | B | serialize | 315.9K | 312.0K-316.5K | 0.78 | 1.22 | 12.7 | 30 | 0 |
| goose-epoll | B | serialize | 247.4K | 245.4K-248.3K | 1.04 | 1.44 | 16.2 | 29 | 0 |
| goose-epoll-rest | B | serialize | 249.5K | 245.9K-251.1K | 1.04 | 1.45 | 16.1 | 29 | 0 |
| goose-uring-rest | B | serialize | 317.9K | 317.4K-318.9K | 0.77 | 1.21 | 12.6 | 30 | 0 |
| goose-uring | B | template | 396.0K | 389.6K-398.8K | 0.62 | 0.95 | 10.1 | 50 | 0 |
| goose-epoll | B | template | 303.7K | 298.9K-304.8K | 0.85 | 1.24 | 13.2 | 50 | 0 |
| goose-epoll-rest | B | template | 307.7K | 305.6K-307.8K | 0.83 | 1.28 | 13.0 | 50 | 0 |
| goose-uring-rest | B | template | 396.6K | 391.8K-399.9K | 0.62 | 0.94 | 10.1 | 50 | 0 |
| goose-uring | C | serialize | 64.0K | 63.8K-64.2K | 3.88 | 8.56 | 62.5 | 71 | 0 |
| goose-epoll | C | serialize | 62.9K | 62.1K-62.9K | 3.94 | 8.16 | 63.8 | 69 | 0 |
| goose-epoll-rest | C | serialize | 61.3K | 61.3K-62.2K | 4.05 | 7.76 | 65.5 | 69 | 0 |
| goose-uring-rest | C | serialize | 62.7K | 62.6K-63.1K | 3.97 | 8.54 | 63.8 | 71 | 0 |
| goose-uring | C | template | 153.4K | 151.1K-155.1K | 1.59 | 3.09 | 26.0 | 58 | 0 |
| goose-epoll | C | template | 145.1K | 145.0K-145.7K | 1.69 | 2.94 | 27.6 | 58 | 0 |
| goose-epoll-rest | C | template | 137.6K | 135.6K-137.7K | 1.79 | 3.17 | 29.1 | 58 | 0 |
| goose-uring-rest | C | template | 147.6K | 146.7K-147.9K | 1.66 | 3.14 | 27.0 | 58 | 0 |

## Tier D

| Server | Run | uploads/s | uploads p50 ms | forms role req/s | forms p99 ms | peak RSS MB | upload errors |
|---|---|---:|---:|---:|---:|---:|---:|
| goose-uring | alone | 1.2K | 15.5-16.5 |  |  | 71 | 0 |
| goose-epoll | alone | 1.2K | 14.4-15.7 |  |  | 69 | 0 |
| goose-epoll-rest | alone | 1.2K | 14.7-16.5 |  |  | 69 | 0 |
| goose-uring-rest | alone | 1.1K | 16.5-16.8 |  |  | 71 | 0 |
| goose-uring | beside forms | 168-169 | 115-118 | 7.5K-7.6K | 66.9-71.2 | 126 | 0 |
| goose-epoll | beside forms | 123-124 | 151-163 | 7.8K-7.9K | 78.7-83.5 | 133 | 0 |
| goose-epoll-rest | beside forms | 114-119 | 160-227 | 7.3K-7.4K | 86.7-89.0 | 150 | 0 |
| goose-uring-rest | beside forms | 154-157 | 129-148 | 6.9K-7.0K | 75.9-80.1 | 121 | 0 |

## Fixed rate

| Server | Tier | Run | Route | rate reached | p50 ms | p99 ms | errors |
|---|---|---|---|---:|---:|---:|---:|
| goose-uring | A | serialize | item | 77.8K of 78.0K | 0.10 | 0.16 | 0 |
| goose-uring | A | serialize | me | 16.0K of 16.0K | 0.09 | 0.15-0.16 | 0 |
| goose-uring | A | serialize | write | 6.0K of 6.0K | 0.10-0.11 | 0.16-0.17 | 0 |
| goose-epoll | A | serialize | item | 77.8K of 78.0K | 0.09-0.10 | 0.16-0.21 | 0 |
| goose-epoll | A | serialize | me | 16.0K of 16.0K | 0.09 | 0.15-0.20 | 0 |
| goose-epoll | A | serialize | write | 6.0K of 6.0K | 0.10-0.11 | 0.16-0.20 | 0 |
| goose-epoll-rest | A | serialize | item | 77.7K-77.8K of 78.0K | 0.09-0.10 | 0.16-0.17 | 0 |
| goose-epoll-rest | A | serialize | me | 16.0K of 16.0K | 0.09 | 0.15-0.16 | 0 |
| goose-epoll-rest | A | serialize | write | 6.0K of 6.0K | 0.10-0.11 | 0.16-0.18 | 0 |
| goose-uring-rest | A | serialize | item | 77.7K-77.9K of 78.0K | 0.10 | 0.16-0.86 | 0 |
| goose-uring-rest | A | serialize | me | 16.0K of 16.0K | 0.09 | 0.16-0.36 | 0 |
| goose-uring-rest | A | serialize | write | 6.0K of 6.0K | 0.11 | 0.16-0.24 | 0 |
| goose-uring | A | template | item | 77.8K-77.9K of 78.0K | 0.09 | 0.16 | 0 |
| goose-uring | A | template | me | 16.0K of 16.0K | 0.09 | 0.15-0.16 | 0 |
| goose-uring | A | template | write | 6.0K of 6.0K | 0.10-0.11 | 0.15-0.16 | 0 |
| goose-epoll | A | template | item | 77.8K-77.9K of 78.0K | 0.09-0.10 | 0.16-5.31 | 0 |
| goose-epoll | A | template | me | 16.0K of 16.0K | 0.09 | 0.15-8.75 | 0 |
| goose-epoll | A | template | write | 6.0K of 6.0K | 0.10-0.11 | 0.16-4.05 | 0 |
| goose-epoll-rest | A | template | item | 77.8K-77.9K of 78.0K | 0.10 | 0.16-0.18 | 0 |
| goose-epoll-rest | A | template | me | 16.0K of 16.0K | 0.09 | 0.16-0.18 | 0 |
| goose-epoll-rest | A | template | write | 6.0K of 6.0K | 0.10-0.11 | 0.16-0.18 | 0 |
| goose-uring-rest | A | template | item | 77.8K of 78.0K | 0.10 | 0.16-0.17 | 0 |
| goose-uring-rest | A | template | me | 16.0K of 16.0K | 0.09 | 0.16-0.17 | 0 |
| goose-uring-rest | A | template | write | 6.0K of 6.0K | 0.11 | 0.16-0.17 | 0 |
| goose-uring | B | serialize | entries | 6.0K of 6.0K | 0.10 | 0.15-0.16 | 0 |
| goose-uring | B | serialize | patch | 2.4K of 2.4K | 0.10 | 0.14 | 0 |
| goose-uring | B | serialize | projects | 3.6K of 3.6K | 0.10 | 0.14 | 0 |
| goose-uring | B | serialize | session | 6.0K of 6.0K | 0.10 | 0.14-0.15 | 0 |
| goose-uring | B | serialize | timer | 6.0K of 6.0K | 0.09-0.10 | 0.14 | 0 |
| goose-epoll | B | serialize | entries | 6.0K of 6.0K | 0.10 | 0.15-0.17 | 0 |
| goose-epoll | B | serialize | patch | 2.4K of 2.4K | 0.10 | 0.14-0.15 | 0 |
| goose-epoll | B | serialize | projects | 3.6K of 3.6K | 0.10 | 0.14-0.15 | 0 |
| goose-epoll | B | serialize | session | 6.0K of 6.0K | 0.10 | 0.14-0.15 | 0 |
| goose-epoll | B | serialize | timer | 6.0K of 6.0K | 0.09-0.10 | 0.14-0.15 | 0 |
| goose-epoll-rest | B | serialize | entries | 6.0K of 6.0K | 0.10-0.11 | 0.14-10.6 | 0 |
| goose-epoll-rest | B | serialize | patch | 2.4K of 2.4K | 0.10 | 0.14-6.07 | 0 |
| goose-epoll-rest | B | serialize | projects | 3.6K of 3.6K | 0.10 | 0.14-6.20 | 0 |
| goose-epoll-rest | B | serialize | session | 6.0K of 6.0K | 0.10 | 0.14-10.5 | 0 |
| goose-epoll-rest | B | serialize | timer | 6.0K of 6.0K | 0.09-0.10 | 0.14-11.9 | 0 |
| goose-uring-rest | B | serialize | entries | 6.0K of 6.0K | 0.11 | 0.15-0.16 | 0 |
| goose-uring-rest | B | serialize | patch | 2.4K of 2.4K | 0.10 | 0.14 | 0 |
| goose-uring-rest | B | serialize | projects | 3.6K of 3.6K | 0.10 | 0.14 | 0 |
| goose-uring-rest | B | serialize | session | 6.0K of 6.0K | 0.10 | 0.14-0.15 | 0 |
| goose-uring-rest | B | serialize | timer | 6.0K of 6.0K | 0.10 | 0.13-0.14 | 0 |
| goose-uring | B | template | entries | 6.0K of 6.0K | 0.10 | 0.14-0.15 | 0 |
| goose-uring | B | template | patch | 2.4K of 2.4K | 0.10 | 0.14-0.15 | 0 |
| goose-uring | B | template | projects | 3.6K of 3.6K | 0.10 | 0.14-0.15 | 0 |
| goose-uring | B | template | session | 6.0K of 6.0K | 0.09 | 0.13-0.14 | 0 |
| goose-uring | B | template | timer | 6.0K of 6.0K | 0.09-0.10 | 0.13-0.15 | 0 |
| goose-epoll | B | template | entries | 6.0K of 6.0K | 0.10 | 0.14 | 0 |
| goose-epoll | B | template | patch | 2.4K of 2.4K | 0.10 | 0.14 | 0 |
| goose-epoll | B | template | projects | 3.6K of 3.6K | 0.10 | 0.14 | 0 |
| goose-epoll | B | template | session | 6.0K of 6.0K | 0.09 | 0.13 | 0 |
| goose-epoll | B | template | timer | 6.0K of 6.0K | 0.09-0.10 | 0.13 | 0 |
| goose-epoll-rest | B | template | entries | 6.0K of 6.0K | 0.10 | 0.14 | 0 |
| goose-epoll-rest | B | template | patch | 2.4K of 2.4K | 0.10 | 0.13-0.14 | 0 |
| goose-epoll-rest | B | template | projects | 3.6K of 3.6K | 0.10 | 0.13 | 0 |
| goose-epoll-rest | B | template | session | 6.0K of 6.0K | 0.09-0.10 | 0.13 | 0 |
| goose-epoll-rest | B | template | timer | 6.0K of 6.0K | 0.09 | 0.13 | 0 |
| goose-uring-rest | B | template | entries | 6.0K of 6.0K | 0.10 | 0.14-0.15 | 0 |
| goose-uring-rest | B | template | patch | 2.4K of 2.4K | 0.10 | 0.14 | 0 |
| goose-uring-rest | B | template | projects | 3.6K of 3.6K | 0.10 | 0.14 | 0 |
| goose-uring-rest | B | template | session | 6.0K of 6.0K | 0.09-0.10 | 0.14 | 0 |
| goose-uring-rest | B | template | timer | 6.0K of 6.0K | 0.09-0.10 | 0.14 | 0 |
| goose-uring | C | serialize | bookings | 153 of 153 | 0.68-0.69 | 0.83-0.84 | 0 |
| goose-uring | C | serialize | client | 51 of 51 | 0.10-0.12 | 0.14-0.52 | 0 |
| goose-uring | C | serialize | encounter | 204 of 204 | 0.12 | 0.17-0.31 | 0 |
| goose-uring | C | serialize | history | 204 of 204 | 0.14 | 0.20-0.65 | 0 |
| goose-uring | C | serialize | poll | 933-935 of 935 | 0.10 | 0.42-0.50 | 0 |
| goose-uring | C | serialize | shifts | 153 of 153 | 0.12 | 0.16-0.17 | 0 |
| goose-epoll | C | serialize | bookings | 153 of 153 | 0.69-0.70 | 0.86-0.95 | 0 |
| goose-epoll | C | serialize | client | 51 of 51 | 0.10-0.12 | 0.15-0.56 | 0 |
| goose-epoll | C | serialize | encounter | 204 of 204 | 0.12 | 0.17-0.27 | 0 |
| goose-epoll | C | serialize | history | 204 of 204 | 0.14 | 0.19-0.72 | 0 |
| goose-epoll | C | serialize | poll | 933-934 of 935 | 0.10 | 0.46-0.53 | 0 |
| goose-epoll | C | serialize | shifts | 153 of 153 | 0.12 | 0.17-0.18 | 0 |
| goose-epoll-rest | C | serialize | bookings | 153 of 153 | 0.67-0.69 | 0.82-0.83 | 0 |
| goose-epoll-rest | C | serialize | client | 51 of 51 | 0.10-0.12 | 0.16-0.45 | 0 |
| goose-epoll-rest | C | serialize | encounter | 204 of 204 | 0.12 | 0.16-0.17 | 0 |
| goose-epoll-rest | C | serialize | history | 204 of 204 | 0.14-0.15 | 0.20-0.46 | 0 |
| goose-epoll-rest | C | serialize | poll | 933-934 of 935 | 0.10 | 0.43-0.47 | 0 |
| goose-epoll-rest | C | serialize | shifts | 153 of 153 | 0.12 | 0.17 | 0 |
| goose-uring-rest | C | serialize | bookings | 153 of 153 | 0.70 | 0.85-0.87 | 0 |
| goose-uring-rest | C | serialize | client | 51 of 51 | 0.10-0.12 | 0.15-0.40 | 0 |
| goose-uring-rest | C | serialize | encounter | 204 of 204 | 0.12 | 0.17-0.19 | 0 |
| goose-uring-rest | C | serialize | history | 204 of 204 | 0.14-0.15 | 0.47-0.66 | 0 |
| goose-uring-rest | C | serialize | poll | 934-935 of 935 | 0.10 | 0.43-0.47 | 0 |
| goose-uring-rest | C | serialize | shifts | 153 of 153 | 0.11-0.12 | 0.16-0.17 | 0 |
| goose-uring | C | template | bookings | 153 of 153 | 0.28 | 0.42-0.43 | 0 |
| goose-uring | C | template | client | 51 of 51 | 0.10-0.12 | 0.14-0.27 | 0 |
| goose-uring | C | template | encounter | 204 of 204 | 0.12 | 0.16-0.17 | 0 |
| goose-uring | C | template | history | 204 of 204 | 0.13 | 0.18-0.25 | 0 |
| goose-uring | C | template | poll | 933-934 of 935 | 0.10 | 0.16-0.18 | 0 |
| goose-uring | C | template | shifts | 153 of 153 | 0.11 | 0.15-0.16 | 0 |
| goose-epoll | C | template | bookings | 153 of 153 | 0.28 | 0.41-0.46 | 0 |
| goose-epoll | C | template | client | 51 of 51 | 0.11-0.12 | 0.17-0.21 | 0 |
| goose-epoll | C | template | encounter | 204 of 204 | 0.12 | 0.16 | 0 |
| goose-epoll | C | template | history | 204 of 204 | 0.13 | 0.17-0.23 | 0 |
| goose-epoll | C | template | poll | 934 of 935 | 0.10 | 0.16-0.17 | 0 |
| goose-epoll | C | template | shifts | 153 of 153 | 0.11 | 0.15-0.16 | 0 |
| goose-epoll-rest | C | template | bookings | 153 of 153 | 0.28 | 0.40-0.42 | 0 |
| goose-epoll-rest | C | template | client | 51 of 51 | 0.11-0.12 | 0.15-0.21 | 0 |
| goose-epoll-rest | C | template | encounter | 204 of 204 | 0.12 | 0.16-0.17 | 0 |
| goose-epoll-rest | C | template | history | 204 of 204 | 0.13 | 0.18-0.24 | 0 |
| goose-epoll-rest | C | template | poll | 933-934 of 935 | 0.10 | 0.17-0.18 | 0 |
| goose-epoll-rest | C | template | shifts | 153 of 153 | 0.11 | 0.15-0.16 | 0 |
| goose-uring-rest | C | template | bookings | 153 of 153 | 0.28 | 0.42-0.45 | 0 |
| goose-uring-rest | C | template | client | 51 of 51 | 0.11 | 0.14-0.17 | 0 |
| goose-uring-rest | C | template | encounter | 204 of 204 | 0.11-0.12 | 0.16-0.17 | 0 |
| goose-uring-rest | C | template | history | 204 of 204 | 0.13 | 0.18-0.24 | 0 |
| goose-uring-rest | C | template | poll | 933-934 of 935 | 0.10 | 0.16-0.19 | 0 |
| goose-uring-rest | C | template | shifts | 153 of 153 | 0.11-0.12 | 0.16 | 0 |

| Server | Tier | Run | CPU µs/req | uploads/s |
|---|---|---|---:|---:|
| goose-uring | A | serialize | 20.8-21.0 |  |
| goose-epoll | A | serialize | 20.2-21.1 |  |
| goose-epoll-rest | A | serialize | 20.8-21.9 |  |
| goose-uring-rest | A | serialize | 21.0-21.2 |  |
| goose-uring | A | template | 20.3-20.4 |  |
| goose-epoll | A | template | 20.2-20.7 |  |
| goose-epoll-rest | A | template | 20.4-21.1 |  |
| goose-uring-rest | A | template | 20.8-21.7 |  |
| goose-uring | B | serialize | 31.3-32.1 |  |
| goose-epoll | B | serialize | 31.5-32.0 |  |
| goose-epoll-rest | B | serialize | 31.8-33.8 |  |
| goose-uring-rest | B | serialize | 32.2-32.6 |  |
| goose-uring | B | template | 30.6-31.0 |  |
| goose-epoll | B | template | 29.7-30.0 |  |
| goose-epoll-rest | B | template | 29.8-30.1 |  |
| goose-uring-rest | B | template | 30.2-31.0 |  |
| goose-uring | C | serialize | 89.4-91.1 |  |
| goose-epoll | C | serialize | 90.7-91.5 |  |
| goose-epoll-rest | C | serialize | 90.6-91.1 |  |
| goose-uring-rest | C | serialize | 91.8-92.6 |  |
| goose-uring | C | template | 51.4-51.8 |  |
| goose-epoll | C | template | 50.6-51.4 |  |
| goose-epoll-rest | C | template | 52.2 |  |
| goose-uring-rest | C | template | 53.4-54.6 |  |

## Mixed run: tier C's reads, alone and beside uploads

| Server | Tier | Run | Route | rate reached | p50 ms | p99 ms | errors |
|---|---|---|---|---:|---:|---:|---:|
| goose-uring | C | alone | bookings | 153 of 153 | 0.68-0.69 | 0.84 | 0 |
| goose-uring | C | alone | client | 51 of 51 | 0.10-0.11 | 0.14-0.32 | 0 |
| goose-uring | C | alone | encounter | 204 of 204 | 0.11-0.12 | 0.16-0.17 | 0 |
| goose-uring | C | alone | history | 204 of 204 | 0.14 | 0.20-0.40 | 0 |
| goose-uring | C | alone | poll | 934 of 935 | 0.10 | 0.44-0.49 | 0 |
| goose-uring | C | alone | shifts | 153 of 153 | 0.11-0.12 | 0.15-0.17 | 0 |
| goose-epoll | C | alone | bookings | 153 of 153 | 0.68-0.70 | 0.85-0.94 | 0 |
| goose-epoll | C | alone | client | 51 of 51 | 0.10-0.12 | 0.17-0.70 | 0 |
| goose-epoll | C | alone | encounter | 204 of 204 | 0.12 | 0.17-0.55 | 0 |
| goose-epoll | C | alone | history | 204 of 204 | 0.14-0.15 | 0.20-0.47 | 0 |
| goose-epoll | C | alone | poll | 933-935 of 935 | 0.10 | 0.45-0.51 | 0 |
| goose-epoll | C | alone | shifts | 153 of 153 | 0.11-0.12 | 0.17-0.18 | 0 |
| goose-epoll-rest | C | alone | bookings | 153 of 153 | 0.69 | 0.83-0.85 | 0 |
| goose-epoll-rest | C | alone | client | 51 of 51 | 0.10-0.12 | 0.14-0.63 | 0 |
| goose-epoll-rest | C | alone | encounter | 204 of 204 | 0.12 | 0.16-0.43 | 0 |
| goose-epoll-rest | C | alone | history | 204 of 204 | 0.14-0.15 | 0.20-0.70 | 0 |
| goose-epoll-rest | C | alone | poll | 933-934 of 935 | 0.10 | 0.47-0.49 | 0 |
| goose-epoll-rest | C | alone | shifts | 153 of 153 | 0.12 | 0.16-0.17 | 0 |
| goose-uring-rest | C | alone | bookings | 153 of 153 | 0.69-0.70 | 0.82-0.84 | 0 |
| goose-uring-rest | C | alone | client | 51 of 51 | 0.11-0.12 | 0.15-0.75 | 0 |
| goose-uring-rest | C | alone | encounter | 204 of 204 | 0.12-0.13 | 0.17-0.53 | 0 |
| goose-uring-rest | C | alone | history | 204 of 204 | 0.14-0.15 | 0.20-0.62 | 0 |
| goose-uring-rest | C | alone | poll | 933-934 of 935 | 0.10 | 0.47-0.50 | 0 |
| goose-uring-rest | C | alone | shifts | 153 of 153 | 0.11-0.12 | 0.17 | 0 |
| goose-uring | C | uploads | bookings | 153 of 153 | 2.09-2.75 | 5.76-7.15 | 0 |
| goose-uring | C | uploads | client | 51 of 51 | 2.19-3.00 | 6.44-8.36 | 0 |
| goose-uring | C | uploads | encounter | 204 of 204 | 2.25-2.40 | 6.59-7.89 | 0 |
| goose-uring | C | uploads | history | 204 of 204 | 1.85-2.25 | 5.18-6.46 | 0 |
| goose-uring | C | uploads | poll | 933 of 935 | 2.34-2.48 | 7.23-8.16 | 0 |
| goose-uring | C | uploads | shifts | 153 of 153 | 2.09-2.41 | 6.31-7.63 | 0 |
| goose-epoll | C | uploads | bookings | 153 of 153 | 0.75-0.76 | 1.22-1.29 | 0 |
| goose-epoll | C | uploads | client | 51 of 51 | 0.15-0.17 | 0.38-0.47 | 0 |
| goose-epoll | C | uploads | encounter | 204 of 204 | 0.18 | 0.43-0.89 | 0 |
| goose-epoll | C | uploads | history | 204 of 204 | 0.20-0.21 | 0.48-0.82 | 0 |
| goose-epoll | C | uploads | poll | 933-934 of 935 | 0.16 | 0.70-0.76 | 0 |
| goose-epoll | C | uploads | shifts | 153 of 153 | 0.17 | 0.42-0.45 | 0 |
| goose-epoll-rest | C | uploads | bookings | 153 of 153 | 0.77-0.80 | 1.36-1.43 | 0 |
| goose-epoll-rest | C | uploads | client | 51 of 51 | 0.19-0.20 | 0.62-0.98 | 0 |
| goose-epoll-rest | C | uploads | encounter | 204 of 204 | 0.19-0.20 | 0.85-0.94 | 0 |
| goose-epoll-rest | C | uploads | history | 204 of 204 | 0.21-0.22 | 0.61-0.92 | 0 |
| goose-epoll-rest | C | uploads | poll | 933-934 of 935 | 0.17-0.18 | 0.82-1.00 | 0 |
| goose-epoll-rest | C | uploads | shifts | 153 of 153 | 0.18-0.19 | 0.51-0.59 | 0 |
| goose-uring-rest | C | uploads | bookings | 153 of 153 | 2.88 | 6.36-7.02 | 0 |
| goose-uring-rest | C | uploads | client | 51 of 51 | 2.36-2.78 | 6.80-7.97 | 0 |
| goose-uring-rest | C | uploads | encounter | 204 of 204 | 2.75-3.04 | 7.38-8.32 | 0 |
| goose-uring-rest | C | uploads | history | 204 of 204 | 2.36-2.51 | 5.61-6.19 | 0 |
| goose-uring-rest | C | uploads | poll | 933-934 of 935 | 2.77-2.86 | 7.63-8.31 | 0 |
| goose-uring-rest | C | uploads | shifts | 153 of 153 | 2.64-2.72 | 7.34-8.41 | 0 |

| Server | Tier | Run | CPU µs/req | uploads/s |
|---|---|---|---:|---:|
| goose-uring | C | alone | 89.1-89.5 |  |
| goose-epoll | C | alone | 89.9-91.0 |  |
| goose-epoll-rest | C | alone | 91.9-92.6 |  |
| goose-uring-rest | C | alone | 91.1-93.0 |  |
| goose-uring | C | uploads | 2253.7-2319.6 | 1.1K-1.2K |
| goose-epoll | C | uploads | 2313.6-2340.2 | 1.2K |
| goose-epoll-rest | C | uploads | 2308.2-2348.3 | 1.1K |
| goose-uring-rest | C | uploads | 2341.1-2351.0 | 1.1K |

