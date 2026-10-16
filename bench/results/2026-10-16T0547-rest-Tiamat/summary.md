## Saturation

| Server | Tier | JSON | req/s, median | range | p50 ms | p99 ms | CPU µs/req | peak RSS MB | errors |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|
| goose-uring | A | serialize | 602.3K | 599.5K-604.1K | 0.36 | 0.63 | 6.6 | 12 | 0 |
| goose-epoll | A | serialize | 450.1K | 450.0K-455.2K | 0.54 | 0.86 | 8.9 | 8 | 0 |
| goose-epoll-rest | A | serialize | 440.7K | 428.8K-448.1K | 0.56 | 0.89 | 9.1 | 8 | 0 |
| goose-uring-rest | A | serialize | 586.1K | 581.8K-589.9K | 0.38 | 0.65 | 6.8 | 13 | 0 |
| goose-uring | A | template | 609.0K | 605.9K-609.4K | 0.36 | 0.60 | 6.5 | 12 | 0 |
| goose-epoll | A | template | 456.5K | 455.9K-469.9K | 0.54 | 0.82 | 8.8 | 8 | 0 |
| goose-epoll-rest | A | template | 451.1K | 446.0K-459.1K | 0.54 | 0.83 | 8.9 | 8 | 0 |
| goose-uring-rest | A | template | 583.9K | 578.7K-594.6K | 0.38 | 0.64 | 6.8 | 12 | 0 |
| goose-uring | B | serialize | 311.3K | 311.2K-315.7K | 0.80 | 1.23 | 12.8 | 30 | 0 |
| goose-epoll | B | serialize | 242.7K | 239.4K-242.9K | 1.09 | 1.51 | 16.5 | 29 | 0 |
| goose-epoll-rest | B | serialize | 240.4K | 238.6K-241.7K | 1.09 | 1.49 | 16.7 | 30 | 0 |
| goose-uring-rest | B | serialize | 310.9K | 309.1K-312.4K | 0.80 | 1.21 | 12.9 | 32 | 0 |
| goose-uring | B | template | 397.7K | 394.0K-398.3K | 0.62 | 0.91 | 10.1 | 50 | 0 |
| goose-epoll | B | template | 299.2K | 291.1K-299.3K | 0.86 | 1.27 | 13.4 | 50 | 0 |
| goose-epoll-rest | B | template | 290.0K | 290.0K-291.8K | 0.88 | 1.24 | 13.8 | 47 | 0 |
| goose-uring-rest | B | template | 391.8K | 391.7K-399.7K | 0.62 | 0.96 | 10.2 | 49 | 0 |
| goose-uring | C | serialize | 62.4K | 62.0K-62.6K | 3.97 | 8.86 | 64.0 | 70 | 0 |
| goose-epoll | C | serialize | 61.2K | 60.9K-61.7K | 4.03 | 8.28 | 65.6 | 69 | 0 |
| goose-epoll-rest | C | serialize | 60.5K | 59.6K-61.1K | 4.08 | 8.31 | 66.4 | 70 | 0 |
| goose-uring-rest | C | serialize | 61.8K | 61.7K-62.3K | 4.01 | 8.84 | 64.6 | 72 | 0 |
| goose-uring | C | template | 147.9K | 145.6K-148.8K | 1.65 | 3.12 | 26.9 | 58 | 0 |
| goose-epoll | C | template | 138.1K | 136.9K-140.1K | 1.80 | 3.12 | 29.0 | 58 | 0 |
| goose-epoll-rest | C | template | 133.4K | 133.2K-134.2K | 1.85 | 3.17 | 30.0 | 58 | 0 |
| goose-uring-rest | C | template | 142.1K | 141.2K-142.4K | 1.73 | 3.27 | 28.0 | 57 | 0 |

## Tier D

| Server | Run | uploads/s | uploads p50 ms | forms role req/s | forms p99 ms | peak RSS MB | upload errors |
|---|---|---:|---:|---:|---:|---:|---:|
| goose-uring | alone | 1.1K-1.2K | 16.4-17.5 |  |  | 70 | 0 |
| goose-epoll | alone | 1.1K-1.2K | 15.2-18.7 |  |  | 69 | 0 |
| goose-epoll-rest | alone | 1.1K | 16.3-18.5 |  |  | 70 | 0 |
| goose-uring-rest | alone | 1.1K | 16.7-18.0 |  |  | 72 | 0 |
| goose-uring | beside forms | 164-165 | 119-126 | 7.4K-7.5K | 70.3-72.0 | 125 | 0 |
| goose-epoll | beside forms | 119-121 | 156-168 | 7.5K | 85.8-88.0 | 132 | 0 |
| goose-epoll-rest | beside forms | 122-126 | 163-246 | 7.7K-8.1K | 79.2-84.2 | 158 | 0 |
| goose-uring-rest | beside forms | 165-175 | 116-124 | 7.2K-7.6K | 72.5-76.1 | 133 | 0 |

## Fixed rate

| Server | Tier | Run | Route | rate reached | p50 ms | p99 ms | errors |
|---|---|---|---|---:|---:|---:|---:|
| goose-uring | A | serialize | item | 77.8K-77.9K of 78.0K | 0.09-0.10 | 0.15 | 0 |
| goose-uring | A | serialize | me | 16.0K of 16.0K | 0.09 | 0.15-0.16 | 0 |
| goose-uring | A | serialize | write | 6.0K of 6.0K | 0.10-0.11 | 0.16 | 0 |
| goose-epoll | A | serialize | item | 77.7K-77.8K of 78.0K | 0.09-0.10 | 0.16-1.63 | 0 |
| goose-epoll | A | serialize | me | 16.0K of 16.0K | 0.09 | 0.15-0.75 | 0 |
| goose-epoll | A | serialize | write | 6.0K of 6.0K | 0.10-0.11 | 0.16-0.38 | 0 |
| goose-epoll-rest | A | serialize | item | 77.8K-77.9K of 78.0K | 0.09-0.10 | 0.16-0.17 | 0 |
| goose-epoll-rest | A | serialize | me | 16.0K of 16.0K | 0.09 | 0.16 | 0 |
| goose-epoll-rest | A | serialize | write | 6.0K of 6.0K | 0.10-0.11 | 0.16 | 0 |
| goose-uring-rest | A | serialize | item | 77.8K-77.9K of 78.0K | 0.10 | 0.15-0.16 | 0 |
| goose-uring-rest | A | serialize | me | 16.0K of 16.0K | 0.09 | 0.15-0.16 | 0 |
| goose-uring-rest | A | serialize | write | 6.0K of 6.0K | 0.11 | 0.16 | 0 |
| goose-uring | A | template | item | 77.8K of 78.0K | 0.09-0.10 | 0.15-0.22 | 0 |
| goose-uring | A | template | me | 16.0K of 16.0K | 0.09 | 0.15-0.20 | 0 |
| goose-uring | A | template | write | 6.0K of 6.0K | 0.10-0.11 | 0.15-0.19 | 0 |
| goose-epoll | A | template | item | 77.8K of 78.0K | 0.09 | 0.15-0.16 | 0 |
| goose-epoll | A | template | me | 16.0K of 16.0K | 0.09 | 0.15-0.16 | 0 |
| goose-epoll | A | template | write | 6.0K of 6.0K | 0.10-0.11 | 0.16-0.17 | 0 |
| goose-epoll-rest | A | template | item | 77.7K-77.8K of 78.0K | 0.09-0.10 | 0.16-0.17 | 0 |
| goose-epoll-rest | A | template | me | 16.0K of 16.0K | 0.09 | 0.16 | 0 |
| goose-epoll-rest | A | template | write | 6.0K of 6.0K | 0.10-0.11 | 0.16 | 0 |
| goose-uring-rest | A | template | item | 77.8K of 78.0K | 0.09-0.10 | 0.16 | 0 |
| goose-uring-rest | A | template | me | 16.0K of 16.0K | 0.09 | 0.15-0.16 | 0 |
| goose-uring-rest | A | template | write | 6.0K of 6.0K | 0.11 | 0.16 | 0 |
| goose-uring | B | serialize | entries | 6.0K of 6.0K | 0.10-0.11 | 0.15 | 0 |
| goose-uring | B | serialize | patch | 2.4K of 2.4K | 0.10 | 0.14 | 0 |
| goose-uring | B | serialize | projects | 3.6K of 3.6K | 0.10 | 0.14 | 0 |
| goose-uring | B | serialize | session | 6.0K of 6.0K | 0.10 | 0.14 | 0 |
| goose-uring | B | serialize | timer | 6.0K of 6.0K | 0.10 | 0.13-0.14 | 0 |
| goose-epoll | B | serialize | entries | 6.0K of 6.0K | 0.10 | 0.14-0.15 | 0 |
| goose-epoll | B | serialize | patch | 2.4K of 2.4K | 0.10 | 0.14 | 0 |
| goose-epoll | B | serialize | projects | 3.6K of 3.6K | 0.10 | 0.14 | 0 |
| goose-epoll | B | serialize | session | 6.0K of 6.0K | 0.10 | 0.14 | 0 |
| goose-epoll | B | serialize | timer | 6.0K of 6.0K | 0.09-0.10 | 0.13-0.14 | 0 |
| goose-epoll-rest | B | serialize | entries | 6.0K of 6.0K | 0.10-0.11 | 0.14-0.15 | 0 |
| goose-epoll-rest | B | serialize | patch | 2.4K of 2.4K | 0.10 | 0.14 | 0 |
| goose-epoll-rest | B | serialize | projects | 3.6K of 3.6K | 0.10 | 0.14 | 0 |
| goose-epoll-rest | B | serialize | session | 6.0K of 6.0K | 0.10 | 0.14 | 0 |
| goose-epoll-rest | B | serialize | timer | 6.0K of 6.0K | 0.10 | 0.13-0.14 | 0 |
| goose-uring-rest | B | serialize | entries | 6.0K of 6.0K | 0.10 | 0.14-0.15 | 0 |
| goose-uring-rest | B | serialize | patch | 2.4K of 2.4K | 0.10 | 0.14-0.15 | 0 |
| goose-uring-rest | B | serialize | projects | 3.6K of 3.6K | 0.10 | 0.14 | 0 |
| goose-uring-rest | B | serialize | session | 6.0K of 6.0K | 0.10 | 0.14 | 0 |
| goose-uring-rest | B | serialize | timer | 6.0K of 6.0K | 0.10 | 0.13-0.15 | 0 |
| goose-uring | B | template | entries | 6.0K of 6.0K | 0.10 | 0.14 | 0 |
| goose-uring | B | template | patch | 2.4K of 2.4K | 0.10 | 0.14 | 0 |
| goose-uring | B | template | projects | 3.6K of 3.6K | 0.10 | 0.14 | 0 |
| goose-uring | B | template | session | 6.0K of 6.0K | 0.10 | 0.13-0.14 | 0 |
| goose-uring | B | template | timer | 6.0K of 6.0K | 0.10 | 0.13 | 0 |
| goose-epoll | B | template | entries | 6.0K of 6.0K | 0.10 | 0.14-0.15 | 0 |
| goose-epoll | B | template | patch | 2.4K of 2.4K | 0.10 | 0.13-0.14 | 0 |
| goose-epoll | B | template | projects | 3.6K of 3.6K | 0.10 | 0.13-0.14 | 0 |
| goose-epoll | B | template | session | 6.0K of 6.0K | 0.10 | 0.13-0.14 | 0 |
| goose-epoll | B | template | timer | 6.0K of 6.0K | 0.09-0.10 | 0.13-0.14 | 0 |
| goose-epoll-rest | B | template | entries | 6.0K of 6.0K | 0.10 | 0.14 | 0 |
| goose-epoll-rest | B | template | patch | 2.4K of 2.4K | 0.10 | 0.14 | 0 |
| goose-epoll-rest | B | template | projects | 3.6K of 3.6K | 0.10 | 0.13-0.14 | 0 |
| goose-epoll-rest | B | template | session | 6.0K of 6.0K | 0.09-0.10 | 0.13 | 0 |
| goose-epoll-rest | B | template | timer | 6.0K of 6.0K | 0.09-0.10 | 0.13-0.14 | 0 |
| goose-uring-rest | B | template | entries | 6.0K of 6.0K | 0.10 | 0.14 | 0 |
| goose-uring-rest | B | template | patch | 2.4K of 2.4K | 0.10 | 0.14 | 0 |
| goose-uring-rest | B | template | projects | 3.6K of 3.6K | 0.10 | 0.14 | 0 |
| goose-uring-rest | B | template | session | 6.0K of 6.0K | 0.10 | 0.14 | 0 |
| goose-uring-rest | B | template | timer | 6.0K of 6.0K | 0.09-0.10 | 0.13-0.14 | 0 |
| goose-uring | C | serialize | bookings | 153 of 153 | 0.68-0.69 | 0.82-0.85 | 0 |
| goose-uring | C | serialize | client | 51 of 51 | 0.11 | 0.15-0.16 | 0 |
| goose-uring | C | serialize | encounter | 204 of 204 | 0.12 | 0.23-0.36 | 0 |
| goose-uring | C | serialize | history | 204 of 204 | 0.14 | 0.44-0.64 | 0 |
| goose-uring | C | serialize | poll | 933-934 of 935 | 0.10 | 0.44-0.47 | 0 |
| goose-uring | C | serialize | shifts | 153 of 153 | 0.11-0.12 | 0.15-0.16 | 0 |
| goose-epoll | C | serialize | bookings | 153 of 153 | 0.68-0.70 | 0.82-0.84 | 0 |
| goose-epoll | C | serialize | client | 51 of 51 | 0.11 | 0.15 | 0 |
| goose-epoll | C | serialize | encounter | 204 of 204 | 0.12 | 0.19-0.55 | 0 |
| goose-epoll | C | serialize | history | 204 of 204 | 0.14 | 0.19-0.62 | 0 |
| goose-epoll | C | serialize | poll | 933-934 of 935 | 0.10 | 0.47-0.51 | 0 |
| goose-epoll | C | serialize | shifts | 153 of 153 | 0.11 | 0.15-0.16 | 0 |
| goose-epoll-rest | C | serialize | bookings | 153 of 153 | 0.67-0.70 | 0.82-0.92 | 0 |
| goose-epoll-rest | C | serialize | client | 51 of 51 | 0.11-0.12 | 0.15-0.17 | 0 |
| goose-epoll-rest | C | serialize | encounter | 204 of 204 | 0.12 | 0.17-0.55 | 0 |
| goose-epoll-rest | C | serialize | history | 204 of 204 | 0.14 | 0.19-0.30 | 0 |
| goose-epoll-rest | C | serialize | poll | 933-934 of 935 | 0.10 | 0.45-0.49 | 0 |
| goose-epoll-rest | C | serialize | shifts | 153 of 153 | 0.11-0.12 | 0.16-0.19 | 0 |
| goose-uring-rest | C | serialize | bookings | 153 of 153 | 0.67-0.69 | 0.81-0.85 | 0 |
| goose-uring-rest | C | serialize | client | 51 of 51 | 0.11-0.12 | 0.15-0.16 | 0 |
| goose-uring-rest | C | serialize | encounter | 204 of 204 | 0.12-0.13 | 0.17-0.45 | 0 |
| goose-uring-rest | C | serialize | history | 204 of 204 | 0.14 | 0.20-0.29 | 0 |
| goose-uring-rest | C | serialize | poll | 933-934 of 935 | 0.10 | 0.42-0.48 | 0 |
| goose-uring-rest | C | serialize | shifts | 153 of 153 | 0.11-0.12 | 0.16-0.18 | 0 |
| goose-uring | C | template | bookings | 153 of 153 | 0.28 | 0.41-0.47 | 0 |
| goose-uring | C | template | client | 51 of 51 | 0.11 | 0.15 | 0 |
| goose-uring | C | template | encounter | 204 of 204 | 0.12 | 0.16-0.17 | 0 |
| goose-uring | C | template | history | 204 of 204 | 0.12-0.13 | 0.17-0.18 | 0 |
| goose-uring | C | template | poll | 933-934 of 935 | 0.10 | 0.17 | 0 |
| goose-uring | C | template | shifts | 153 of 153 | 0.10 | 0.14-0.15 | 0 |
| goose-epoll | C | template | bookings | 153 of 153 | 0.28 | 0.41-0.43 | 0 |
| goose-epoll | C | template | client | 51 of 51 | 0.10-0.11 | 0.15 | 0 |
| goose-epoll | C | template | encounter | 204 of 204 | 0.12 | 0.16-0.17 | 0 |
| goose-epoll | C | template | history | 204 of 204 | 0.13 | 0.21-0.26 | 0 |
| goose-epoll | C | template | poll | 933-934 of 935 | 0.10 | 0.16-0.18 | 0 |
| goose-epoll | C | template | shifts | 153 of 153 | 0.10-0.11 | 0.15-0.16 | 0 |
| goose-epoll-rest | C | template | bookings | 153 of 153 | 0.28 | 0.41-0.43 | 0 |
| goose-epoll-rest | C | template | client | 51 of 51 | 0.11-0.12 | 0.15-0.16 | 0 |
| goose-epoll-rest | C | template | encounter | 204 of 204 | 0.11-0.12 | 0.16-0.17 | 0 |
| goose-epoll-rest | C | template | history | 204 of 204 | 0.13-0.14 | 0.17-0.19 | 0 |
| goose-epoll-rest | C | template | poll | 934 of 935 | 0.10 | 0.16-0.18 | 0 |
| goose-epoll-rest | C | template | shifts | 153 of 153 | 0.10 | 0.14-0.15 | 0 |
| goose-uring-rest | C | template | bookings | 153 of 153 | 0.28 | 0.43 | 0 |
| goose-uring-rest | C | template | client | 51 of 51 | 0.11 | 0.15-0.17 | 0 |
| goose-uring-rest | C | template | encounter | 204 of 204 | 0.12 | 0.17 | 0 |
| goose-uring-rest | C | template | history | 204 of 204 | 0.13 | 0.17-0.18 | 0 |
| goose-uring-rest | C | template | poll | 933-934 of 935 | 0.10 | 0.16-0.19 | 0 |
| goose-uring-rest | C | template | shifts | 153 of 153 | 0.10 | 0.14-0.16 | 0 |

| Server | Tier | Run | CPU µs/req | uploads/s |
|---|---|---|---:|---:|
| goose-uring | A | serialize | 20.7-21.6 |  |
| goose-epoll | A | serialize | 20.2-21.3 |  |
| goose-epoll-rest | A | serialize | 20.5-20.9 |  |
| goose-uring-rest | A | serialize | 20.8-21.3 |  |
| goose-uring | A | template | 20.3-20.6 |  |
| goose-epoll | A | template | 19.8-20.5 |  |
| goose-epoll-rest | A | template | 20.2-20.9 |  |
| goose-uring-rest | A | template | 19.8-20.7 |  |
| goose-uring | B | serialize | 31.9-32.5 |  |
| goose-epoll | B | serialize | 31.2-31.5 |  |
| goose-epoll-rest | B | serialize | 31.6-32.3 |  |
| goose-uring-rest | B | serialize | 31.6-32.2 |  |
| goose-uring | B | template | 30.1-30.4 |  |
| goose-epoll | B | template | 29.4-30.2 |  |
| goose-epoll-rest | B | template | 30.0-30.5 |  |
| goose-uring-rest | B | template | 30.0-30.8 |  |
| goose-uring | C | serialize | 89.9-90.7 |  |
| goose-epoll | C | serialize | 89.1-91.0 |  |
| goose-epoll-rest | C | serialize | 89.9-91.8 |  |
| goose-uring-rest | C | serialize | 90.7-91.8 |  |
| goose-uring | C | template | 51.4-52.6 |  |
| goose-epoll | C | template | 51.0-52.2 |  |
| goose-epoll-rest | C | template | 52.2-52.6 |  |
| goose-uring-rest | C | template | 52.2-53.0 |  |

## Mixed run: tier C's reads, alone and beside uploads

| Server | Tier | Run | Route | rate reached | p50 ms | p99 ms | errors |
|---|---|---|---|---:|---:|---:|---:|
| goose-uring | C | alone | bookings | 153 of 153 | 0.67-0.70 | 0.82-0.84 | 0 |
| goose-uring | C | alone | client | 51 of 51 | 0.11-0.12 | 0.15-0.16 | 0 |
| goose-uring | C | alone | encounter | 204 of 204 | 0.12 | 0.42-0.62 | 0 |
| goose-uring | C | alone | history | 204 of 204 | 0.14 | 0.19-0.56 | 0 |
| goose-uring | C | alone | poll | 933-934 of 935 | 0.10 | 0.43-0.49 | 0 |
| goose-uring | C | alone | shifts | 153 of 153 | 0.11-0.12 | 0.16-0.17 | 0 |
| goose-epoll | C | alone | bookings | 153 of 153 | 0.67-0.69 | 0.83-0.84 | 0 |
| goose-epoll | C | alone | client | 51 of 51 | 0.10-0.11 | 0.14-0.15 | 0 |
| goose-epoll | C | alone | encounter | 204 of 204 | 0.12 | 0.29-0.33 | 0 |
| goose-epoll | C | alone | history | 204 of 204 | 0.14 | 0.20-0.45 | 0 |
| goose-epoll | C | alone | poll | 933-934 of 935 | 0.10 | 0.47-0.52 | 0 |
| goose-epoll | C | alone | shifts | 153 of 153 | 0.11 | 0.15-0.17 | 0 |
| goose-epoll-rest | C | alone | bookings | 153 of 153 | 0.68-0.70 | 0.83 | 0 |
| goose-epoll-rest | C | alone | client | 51 of 51 | 0.11 | 0.15-0.16 | 0 |
| goose-epoll-rest | C | alone | encounter | 204 of 204 | 0.12 | 0.17-0.64 | 0 |
| goose-epoll-rest | C | alone | history | 204 of 204 | 0.14 | 0.19-0.58 | 0 |
| goose-epoll-rest | C | alone | poll | 933-934 of 935 | 0.10 | 0.47-0.53 | 0 |
| goose-epoll-rest | C | alone | shifts | 153 of 153 | 0.11-0.12 | 0.16-0.17 | 0 |
| goose-uring-rest | C | alone | bookings | 153 of 153 | 0.68-0.69 | 0.83-0.86 | 0 |
| goose-uring-rest | C | alone | client | 51 of 51 | 0.11 | 0.16 | 0 |
| goose-uring-rest | C | alone | encounter | 204 of 204 | 0.12-0.13 | 0.17-0.64 | 0 |
| goose-uring-rest | C | alone | history | 204 of 204 | 0.14 | 0.19-0.61 | 0 |
| goose-uring-rest | C | alone | poll | 933-934 of 935 | 0.10 | 0.47-0.51 | 0 |
| goose-uring-rest | C | alone | shifts | 153 of 153 | 0.11-0.12 | 0.15-0.17 | 0 |
| goose-uring | C | uploads | bookings | 153 of 153 | 2.36-2.87 | 6.62-8.48 | 0 |
| goose-uring | C | uploads | client | 51 of 51 | 2.16-3.09 | 8.00-10.6 | 0 |
| goose-uring | C | uploads | encounter | 204 of 204 | 2.21-2.74 | 7.80-9.03 | 0 |
| goose-uring | C | uploads | history | 204 of 204 | 1.72-2.35 | 6.03-7.68 | 0 |
| goose-uring | C | uploads | poll | 933-934 of 935 | 2.35-2.78 | 8.27-9.42 | 0 |
| goose-uring | C | uploads | shifts | 153 of 153 | 2.21-2.68 | 7.37-10.2 | 0 |
| goose-epoll | C | uploads | bookings | 153 of 153 | 0.77-0.79 | 1.28-1.29 | 0 |
| goose-epoll | C | uploads | client | 51 of 51 | 0.18-0.19 | 0.49-0.58 | 0 |
| goose-epoll | C | uploads | encounter | 204 of 204 | 0.18-0.20 | 0.60-0.89 | 0 |
| goose-epoll | C | uploads | history | 204 of 204 | 0.21-0.24 | 0.88-1.01 | 0 |
| goose-epoll | C | uploads | poll | 933-934 of 935 | 0.17-0.18 | 0.79-0.82 | 0 |
| goose-epoll | C | uploads | shifts | 153 of 153 | 0.18-0.19 | 0.47-0.51 | 0 |
| goose-epoll-rest | C | uploads | bookings | 153 of 153 | 0.77-0.80 | 1.32-1.39 | 0 |
| goose-epoll-rest | C | uploads | client | 51 of 51 | 0.18-0.21 | 0.50-0.53 | 0 |
| goose-epoll-rest | C | uploads | encounter | 204 of 204 | 0.18-0.21 | 0.86-1.02 | 0 |
| goose-epoll-rest | C | uploads | history | 204 of 204 | 0.23-0.26 | 0.59-0.83 | 0 |
| goose-epoll-rest | C | uploads | poll | 933-934 of 935 | 0.18-0.19 | 0.80-0.99 | 0 |
| goose-epoll-rest | C | uploads | shifts | 153 of 153 | 0.18-0.21 | 0.51-0.60 | 0 |
| goose-uring-rest | C | uploads | bookings | 153 of 153 | 2.90-3.14 | 6.83-8.46 | 0 |
| goose-uring-rest | C | uploads | client | 51 of 51 | 2.10-2.75 | 7.90-8.80 | 0 |
| goose-uring-rest | C | uploads | encounter | 204 of 204 | 2.56-2.86 | 8.32-8.88 | 0 |
| goose-uring-rest | C | uploads | history | 204 of 204 | 1.41-2.40 | 6.47-7.10 | 0 |
| goose-uring-rest | C | uploads | poll | 933 of 935 | 2.17-3.00 | 8.61-8.70 | 0 |
| goose-uring-rest | C | uploads | shifts | 153 of 153 | 1.34-2.74 | 8.13-8.40 | 0 |

| Server | Tier | Run | CPU µs/req | uploads/s |
|---|---|---|---:|---:|
| goose-uring | C | alone | 90.2-91.0 |  |
| goose-epoll | C | alone | 89.1-90.3 |  |
| goose-epoll-rest | C | alone | 89.9-92.2 |  |
| goose-uring-rest | C | alone | 90.3-92.6 |  |
| goose-uring | C | uploads | 2308.4-2338.6 | 1.1K |
| goose-epoll | C | uploads | 2323.7-2352.7 | 1.1K |
| goose-epoll-rest | C | uploads | 2345.4-2360.1 | 1.1K |
| goose-uring-rest | C | uploads | 2286.1-2340.2 | 1.1K |

