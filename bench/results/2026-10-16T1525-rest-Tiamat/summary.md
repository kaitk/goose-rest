## Saturation

| Server | Tier | JSON | req/s, median | range | p50 ms | p99 ms | CPU µs/req | peak RSS MB | errors |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|
| goose-uring | A | serialize | 587.5K | 586.7K-589.8K | 0.38 | 0.71 | 6.7 | 12 | 0 |
| goose-epoll | A | serialize | 428.8K | 426.2K-432.3K | 0.57 | 0.93 | 9.3 | 7 | 0 |
| goose-epoll-rest | A | serialize | 420.5K | 418.0K-425.2K | 0.60 | 0.89 | 9.5 | 8 | 0 |
| goose-uring-rest | A | serialize | 578.7K | 570.0K-588.1K | 0.40 | 0.66 | 6.9 | 13 | 0 |
| goose-uring | A | template | 605.6K | 601.1K-619.7K | 0.35 | 0.63 | 6.5 | 12 | 0 |
| goose-epoll | A | template | 454.9K | 450.8K-461.7K | 0.55 | 0.82 | 8.8 | 8 | 0 |
| goose-epoll-rest | A | template | 442.9K | 427.2K-455.5K | 0.56 | 0.89 | 9.0 | 8 | 0 |
| goose-uring-rest | A | template | 592.0K | 578.9K-597.9K | 0.38 | 0.63 | 6.7 | 12 | 0 |
| goose-uring | B | serialize | 310.9K | 307.6K-312.5K | 0.80 | 1.21 | 12.9 | 30 | 0 |
| goose-epoll | B | serialize | 240.1K | 239.5K-240.1K | 1.03 | 1.58 | 16.7 | 29 | 0 |
| goose-epoll-rest | B | serialize | 240.7K | 238.4K-245.3K | 1.06 | 1.52 | 16.7 | 29 | 0 |
| goose-uring-rest | B | serialize | 311.3K | 307.7K-314.0K | 0.80 | 1.21 | 12.8 | 30 | 0 |
| goose-uring | B | template | 380.4K | 375.1K-381.2K | 0.65 | 0.97 | 10.5 | 50 | 0 |
| goose-epoll | B | template | 288.7K | 287.9K-289.7K | 0.90 | 1.27 | 13.9 | 50 | 0 |
| goose-epoll-rest | B | template | 286.3K | 269.2K-289.2K | 0.93 | 1.22 | 14.0 | 50 | 0 |
| goose-uring-rest | B | template | 381.6K | 378.6K-387.7K | 0.64 | 1.00 | 10.5 | 50 | 0 |
| goose-uring | C | serialize | 62.1K | 61.7K-62.8K | 3.98 | 8.71 | 64.3 | 71 | 0 |
| goose-epoll | C | serialize | 61.4K | 60.9K-61.5K | 4.03 | 8.18 | 65.3 | 69 | 0 |
| goose-epoll-rest | C | serialize | 59.7K | 59.4K-59.9K | 4.15 | 8.69 | 67.2 | 69 | 0 |
| goose-uring-rest | C | serialize | 61.3K | 60.7K-61.3K | 4.05 | 8.81 | 65.2 | 71 | 0 |
| goose-uring | C | template | 147.0K | 144.4K-149.6K | 1.67 | 3.14 | 27.1 | 58 | 0 |
| goose-epoll | C | template | 136.3K | 134.4K-141.1K | 1.81 | 3.11 | 29.3 | 58 | 0 |
| goose-epoll-rest | C | template | 131.3K | 130.1K-133.0K | 1.89 | 3.16 | 30.5 | 58 | 0 |
| goose-uring-rest | C | template | 140.4K | 140.2K-141.3K | 1.76 | 3.27 | 28.3 | 58 | 0 |

## Tier D

| Server | Run | uploads/s | uploads p50 ms | forms role req/s | forms p99 ms | peak RSS MB | upload errors |
|---|---|---:|---:|---:|---:|---:|---:|
| goose-uring | alone | 1.1K-1.2K | 15.8-17.4 |  |  | 71 | 0 |
| goose-epoll | alone | 1.2K | 14.5-16.0 |  |  | 69 | 0 |
| goose-epoll-rest | alone | 1.1K-1.2K | 15.1-16.0 |  |  | 69 | 0 |
| goose-uring-rest | alone | 1.1K | 16.3-17.8 |  |  | 71 | 0 |
| goose-uring | beside forms | 175-178 | 112-123 | 7.7K-7.8K | 64.7-68.9 | 125 | 0 |
| goose-epoll | beside forms | 124-126 | 159-247 | 8.1K-8.3K | 76.8-81.4 | 134 | 0 |
| goose-epoll-rest | beside forms | 116-121 | 158-177 | 7.4K-7.5K | 86.5-89.5 | 149 | 0 |
| goose-uring-rest | beside forms | 159-160 | 116-130 | 7.1K | 70.3-77.0 | 123 | 0 |

## Fixed rate

| Server | Tier | Run | Route | rate reached | p50 ms | p99 ms | errors |
|---|---|---|---|---:|---:|---:|---:|
| goose-uring | A | serialize | item | 77.8K of 78.0K | 0.10 | 0.17-0.56 | 0 |
| goose-uring | A | serialize | me | 16.0K of 16.0K | 0.09-0.10 | 0.16-0.53 | 0 |
| goose-uring | A | serialize | write | 6.0K of 6.0K | 0.11 | 0.17-0.43 | 0 |
| goose-epoll | A | serialize | item | 77.7K-77.8K of 78.0K | 0.10 | 0.16-0.20 | 0 |
| goose-epoll | A | serialize | me | 16.0K of 16.0K | 0.09 | 0.16-0.18 | 0 |
| goose-epoll | A | serialize | write | 6.0K of 6.0K | 0.11 | 0.16-0.18 | 0 |
| goose-epoll-rest | A | serialize | item | 77.8K of 78.0K | 0.10 | 0.15-1.84 | 0 |
| goose-epoll-rest | A | serialize | me | 16.0K of 16.0K | 0.09 | 0.16-0.45 | 0 |
| goose-epoll-rest | A | serialize | write | 6.0K of 6.0K | 0.11 | 0.16-0.73 | 0 |
| goose-uring-rest | A | serialize | item | 77.7K-77.8K of 78.0K | 0.10 | 0.16 | 0 |
| goose-uring-rest | A | serialize | me | 16.0K of 16.0K | 0.09-0.10 | 0.15-0.16 | 0 |
| goose-uring-rest | A | serialize | write | 6.0K of 6.0K | 0.10-0.11 | 0.16 | 0 |
| goose-uring | A | template | item | 77.8K of 78.0K | 0.09-0.10 | 0.15-0.16 | 0 |
| goose-uring | A | template | me | 16.0K of 16.0K | 0.09 | 0.15-0.16 | 0 |
| goose-uring | A | template | write | 6.0K of 6.0K | 0.11 | 0.16 | 0 |
| goose-epoll | A | template | item | 77.8K of 78.0K | 0.09-0.10 | 0.16-0.17 | 0 |
| goose-epoll | A | template | me | 16.0K of 16.0K | 0.09 | 0.16 | 0 |
| goose-epoll | A | template | write | 6.0K of 6.0K | 0.10-0.11 | 0.16-0.17 | 0 |
| goose-epoll-rest | A | template | item | 77.8K of 78.0K | 0.10 | 0.16 | 0 |
| goose-epoll-rest | A | template | me | 16.0K of 16.0K | 0.09 | 0.16 | 0 |
| goose-epoll-rest | A | template | write | 6.0K of 6.0K | 0.11 | 0.16-0.17 | 0 |
| goose-uring-rest | A | template | item | 77.8K-77.9K of 78.0K | 0.09-0.10 | 0.15-0.17 | 0 |
| goose-uring-rest | A | template | me | 16.0K of 16.0K | 0.09 | 0.15-0.16 | 0 |
| goose-uring-rest | A | template | write | 6.0K of 6.0K | 0.11 | 0.16-0.17 | 0 |
| goose-uring | B | serialize | entries | 6.0K of 6.0K | 0.10-0.11 | 0.14-0.15 | 0 |
| goose-uring | B | serialize | patch | 2.4K of 2.4K | 0.10 | 0.14-0.15 | 0 |
| goose-uring | B | serialize | projects | 3.6K of 3.6K | 0.10 | 0.14 | 0 |
| goose-uring | B | serialize | session | 6.0K of 6.0K | 0.10 | 0.14 | 0 |
| goose-uring | B | serialize | timer | 6.0K of 6.0K | 0.09-0.10 | 0.14 | 0 |
| goose-epoll | B | serialize | entries | 6.0K of 6.0K | 0.10 | 0.14-0.15 | 0 |
| goose-epoll | B | serialize | patch | 2.4K of 2.4K | 0.10 | 0.14 | 0 |
| goose-epoll | B | serialize | projects | 3.6K of 3.6K | 0.10 | 0.14 | 0 |
| goose-epoll | B | serialize | session | 6.0K of 6.0K | 0.10 | 0.13-0.14 | 0 |
| goose-epoll | B | serialize | timer | 6.0K of 6.0K | 0.09-0.10 | 0.14 | 0 |
| goose-epoll-rest | B | serialize | entries | 6.0K of 6.0K | 0.10 | 0.15 | 0 |
| goose-epoll-rest | B | serialize | patch | 2.4K of 2.4K | 0.10 | 0.14 | 0 |
| goose-epoll-rest | B | serialize | projects | 3.6K of 3.6K | 0.10 | 0.14 | 0 |
| goose-epoll-rest | B | serialize | session | 6.0K of 6.0K | 0.10 | 0.14 | 0 |
| goose-epoll-rest | B | serialize | timer | 6.0K of 6.0K | 0.09-0.10 | 0.13-0.14 | 0 |
| goose-uring-rest | B | serialize | entries | 6.0K of 6.0K | 0.10-0.11 | 0.14-0.16 | 0 |
| goose-uring-rest | B | serialize | patch | 2.4K of 2.4K | 0.10 | 0.14-0.15 | 0 |
| goose-uring-rest | B | serialize | projects | 3.6K of 3.6K | 0.10 | 0.14 | 0 |
| goose-uring-rest | B | serialize | session | 6.0K of 6.0K | 0.10 | 0.14 | 0 |
| goose-uring-rest | B | serialize | timer | 6.0K of 6.0K | 0.10 | 0.14 | 0 |
| goose-uring | B | template | entries | 6.0K of 6.0K | 0.10 | 0.14-0.15 | 0 |
| goose-uring | B | template | patch | 2.4K of 2.4K | 0.10 | 0.14 | 0 |
| goose-uring | B | template | projects | 3.6K of 3.6K | 0.10 | 0.14 | 0 |
| goose-uring | B | template | session | 6.0K of 6.0K | 0.10 | 0.14 | 0 |
| goose-uring | B | template | timer | 6.0K of 6.0K | 0.09-0.10 | 0.13-0.14 | 0 |
| goose-epoll | B | template | entries | 6.0K of 6.0K | 0.10 | 0.14 | 0 |
| goose-epoll | B | template | patch | 2.4K of 2.4K | 0.10 | 0.14 | 0 |
| goose-epoll | B | template | projects | 3.6K of 3.6K | 0.10 | 0.14 | 0 |
| goose-epoll | B | template | session | 6.0K of 6.0K | 0.09-0.10 | 0.13-0.14 | 0 |
| goose-epoll | B | template | timer | 6.0K of 6.0K | 0.09-0.10 | 0.13 | 0 |
| goose-epoll-rest | B | template | entries | 6.0K of 6.0K | 0.10 | 0.14 | 0 |
| goose-epoll-rest | B | template | patch | 2.4K of 2.4K | 0.10 | 0.14 | 0 |
| goose-epoll-rest | B | template | projects | 3.6K of 3.6K | 0.10 | 0.13-0.14 | 0 |
| goose-epoll-rest | B | template | session | 6.0K of 6.0K | 0.09-0.10 | 0.13-0.14 | 0 |
| goose-epoll-rest | B | template | timer | 6.0K of 6.0K | 0.09 | 0.13-0.14 | 0 |
| goose-uring-rest | B | template | entries | 6.0K of 6.0K | 0.10 | 0.14 | 0 |
| goose-uring-rest | B | template | patch | 2.4K of 2.4K | 0.10 | 0.14 | 0 |
| goose-uring-rest | B | template | projects | 3.6K of 3.6K | 0.10 | 0.13-0.14 | 0 |
| goose-uring-rest | B | template | session | 6.0K of 6.0K | 0.09-0.10 | 0.13-0.14 | 0 |
| goose-uring-rest | B | template | timer | 6.0K of 6.0K | 0.09-0.10 | 0.13-0.14 | 0 |
| goose-uring | C | serialize | bookings | 153 of 153 | 0.68-0.70 | 0.84-0.87 | 0 |
| goose-uring | C | serialize | client | 51 of 51 | 0.11-0.12 | 0.16-0.69 | 0 |
| goose-uring | C | serialize | encounter | 204 of 204 | 0.12 | 0.17-0.62 | 0 |
| goose-uring | C | serialize | history | 204 of 204 | 0.14 | 0.20-0.71 | 0 |
| goose-uring | C | serialize | poll | 933 of 935 | 0.10 | 0.47-0.51 | 0 |
| goose-uring | C | serialize | shifts | 153 of 153 | 0.11-0.12 | 0.15-0.17 | 0 |
| goose-epoll | C | serialize | bookings | 153 of 153 | 0.68-0.69 | 0.82-0.94 | 0 |
| goose-epoll | C | serialize | client | 51 of 51 | 0.10-0.11 | 0.13-0.17 | 0 |
| goose-epoll | C | serialize | encounter | 204 of 204 | 0.12 | 0.16-0.56 | 0 |
| goose-epoll | C | serialize | history | 204 of 204 | 0.14 | 0.20-0.58 | 0 |
| goose-epoll | C | serialize | poll | 933-934 of 935 | 0.10 | 0.47-0.48 | 0 |
| goose-epoll | C | serialize | shifts | 153 of 153 | 0.11-0.12 | 0.16-0.18 | 0 |
| goose-epoll-rest | C | serialize | bookings | 153 of 153 | 0.67-0.70 | 0.82-0.88 | 0 |
| goose-epoll-rest | C | serialize | client | 51 of 51 | 0.12 | 0.60-0.72 | 0 |
| goose-epoll-rest | C | serialize | encounter | 204 of 204 | 0.12 | 0.17-0.19 | 0 |
| goose-epoll-rest | C | serialize | history | 204 of 204 | 0.14-0.15 | 0.19-0.65 | 0 |
| goose-epoll-rest | C | serialize | poll | 933-934 of 935 | 0.10 | 0.46-0.49 | 0 |
| goose-epoll-rest | C | serialize | shifts | 153 of 153 | 0.12 | 0.17 | 0 |
| goose-uring-rest | C | serialize | bookings | 153 of 153 | 0.69 | 0.82-0.88 | 0 |
| goose-uring-rest | C | serialize | client | 51 of 51 | 0.11-0.12 | 0.16-0.72 | 0 |
| goose-uring-rest | C | serialize | encounter | 204 of 204 | 0.12 | 0.17-0.54 | 0 |
| goose-uring-rest | C | serialize | history | 204 of 204 | 0.14-0.15 | 0.20-0.66 | 0 |
| goose-uring-rest | C | serialize | poll | 934-935 of 935 | 0.10 | 0.45-0.48 | 0 |
| goose-uring-rest | C | serialize | shifts | 153 of 153 | 0.11-0.12 | 0.16-0.18 | 0 |
| goose-uring | C | template | bookings | 153 of 153 | 0.28 | 0.41-0.44 | 0 |
| goose-uring | C | template | client | 51 of 51 | 0.11 | 0.22-0.26 | 0 |
| goose-uring | C | template | encounter | 204 of 204 | 0.12 | 0.16-0.17 | 0 |
| goose-uring | C | template | history | 204 of 204 | 0.13 | 0.17-0.24 | 0 |
| goose-uring | C | template | poll | 934-935 of 935 | 0.10 | 0.16-0.17 | 0 |
| goose-uring | C | template | shifts | 153 of 153 | 0.11 | 0.15-0.16 | 0 |
| goose-epoll | C | template | bookings | 153 of 153 | 0.28 | 0.40-0.43 | 0 |
| goose-epoll | C | template | client | 51 of 51 | 0.10-0.11 | 0.14-0.16 | 0 |
| goose-epoll | C | template | encounter | 204 of 204 | 0.11-0.12 | 0.16-0.17 | 0 |
| goose-epoll | C | template | history | 204 of 204 | 0.13 | 0.17-0.23 | 0 |
| goose-epoll | C | template | poll | 933-934 of 935 | 0.10 | 0.16-0.18 | 0 |
| goose-epoll | C | template | shifts | 153 of 153 | 0.11 | 0.15-0.16 | 0 |
| goose-epoll-rest | C | template | bookings | 153 of 153 | 0.28-0.29 | 0.40-0.45 | 0 |
| goose-epoll-rest | C | template | client | 51 of 51 | 0.11-0.12 | 0.16-0.28 | 0 |
| goose-epoll-rest | C | template | encounter | 204 of 204 | 0.11-0.12 | 0.16-0.17 | 0 |
| goose-epoll-rest | C | template | history | 204 of 204 | 0.13 | 0.18-0.22 | 0 |
| goose-epoll-rest | C | template | poll | 933 of 935 | 0.10 | 0.17-0.19 | 0 |
| goose-epoll-rest | C | template | shifts | 153 of 153 | 0.11 | 0.16-0.17 | 0 |
| goose-uring-rest | C | template | bookings | 153 of 153 | 0.28-0.29 | 0.45-0.47 | 0 |
| goose-uring-rest | C | template | client | 51 of 51 | 0.11-0.12 | 0.14-0.27 | 0 |
| goose-uring-rest | C | template | encounter | 204 of 204 | 0.12 | 0.17-0.18 | 0 |
| goose-uring-rest | C | template | history | 204 of 204 | 0.13 | 0.18-0.20 | 0 |
| goose-uring-rest | C | template | poll | 934 of 935 | 0.10 | 0.16-0.19 | 0 |
| goose-uring-rest | C | template | shifts | 153 of 153 | 0.11 | 0.16-0.17 | 0 |

| Server | Tier | Run | CPU µs/req | uploads/s |
|---|---|---|---:|---:|
| goose-uring | A | serialize | 20.8-22.4 |  |
| goose-epoll | A | serialize | 20.5-21.2 |  |
| goose-epoll-rest | A | serialize | 21.1-22.1 |  |
| goose-uring-rest | A | serialize | 21.0-21.7 |  |
| goose-uring | A | template | 20.8-21.1 |  |
| goose-epoll | A | template | 20.4-20.8 |  |
| goose-epoll-rest | A | template | 20.9-21.4 |  |
| goose-uring-rest | A | template | 21.1-21.4 |  |
| goose-uring | B | serialize | 31.5-32.3 |  |
| goose-epoll | B | serialize | 31.0-31.6 |  |
| goose-epoll-rest | B | serialize | 31.8-32.4 |  |
| goose-uring-rest | B | serialize | 32.0-32.3 |  |
| goose-uring | B | template | 30.5-30.6 |  |
| goose-epoll | B | template | 29.6-30.0 |  |
| goose-epoll-rest | B | template | 30.1-30.3 |  |
| goose-uring-rest | B | template | 30.2-30.8 |  |
| goose-uring | C | serialize | 89.9-90.7 |  |
| goose-epoll | C | serialize | 88.7-89.9 |  |
| goose-epoll-rest | C | serialize | 90.3-91.8 |  |
| goose-uring-rest | C | serialize | 91.0-92.2 |  |
| goose-uring | C | template | 51.4-51.8 |  |
| goose-epoll | C | template | 50.6-51.0 |  |
| goose-epoll-rest | C | template | 52.6-53.4 |  |
| goose-uring-rest | C | template | 53.0-54.1 |  |

## Mixed run: tier C's reads, alone and beside uploads

| Server | Tier | Run | Route | rate reached | p50 ms | p99 ms | errors |
|---|---|---|---|---:|---:|---:|---:|
| goose-uring | C | alone | bookings | 153 of 153 | 0.68-0.70 | 0.84-0.85 | 0 |
| goose-uring | C | alone | client | 51 of 51 | 0.11-0.12 | 0.14-0.73 | 0 |
| goose-uring | C | alone | encounter | 204 of 204 | 0.12 | 0.19-0.38 | 0 |
| goose-uring | C | alone | history | 204 of 204 | 0.14-0.15 | 0.20-0.61 | 0 |
| goose-uring | C | alone | poll | 933-934 of 935 | 0.10 | 0.47-0.49 | 0 |
| goose-uring | C | alone | shifts | 153 of 153 | 0.12 | 0.16-0.17 | 0 |
| goose-epoll | C | alone | bookings | 153 of 153 | 0.69 | 0.82-0.86 | 0 |
| goose-epoll | C | alone | client | 51 of 51 | 0.11-0.12 | 0.15-0.71 | 0 |
| goose-epoll | C | alone | encounter | 204 of 204 | 0.12 | 0.17-0.20 | 0 |
| goose-epoll | C | alone | history | 204 of 204 | 0.14 | 0.18-0.68 | 0 |
| goose-epoll | C | alone | poll | 933-934 of 935 | 0.10 | 0.43-0.51 | 0 |
| goose-epoll | C | alone | shifts | 153 of 153 | 0.11-0.12 | 0.15-0.17 | 0 |
| goose-epoll-rest | C | alone | bookings | 153 of 153 | 0.67-0.68 | 0.82-0.88 | 0 |
| goose-epoll-rest | C | alone | client | 51 of 51 | 0.11 | 0.14-0.17 | 0 |
| goose-epoll-rest | C | alone | encounter | 204 of 204 | 0.12 | 0.33-0.60 | 0 |
| goose-epoll-rest | C | alone | history | 204 of 204 | 0.14-0.15 | 0.20-0.23 | 0 |
| goose-epoll-rest | C | alone | poll | 933-934 of 935 | 0.10 | 0.43-0.46 | 0 |
| goose-epoll-rest | C | alone | shifts | 153 of 153 | 0.11-0.12 | 0.16-0.18 | 0 |
| goose-uring-rest | C | alone | bookings | 153 of 153 | 0.63-0.70 | 0.80-0.84 | 0 |
| goose-uring-rest | C | alone | client | 51 of 51 | 0.11-0.12 | 0.16-0.72 | 0 |
| goose-uring-rest | C | alone | encounter | 204 of 204 | 0.12 | 0.17 | 0 |
| goose-uring-rest | C | alone | history | 204 of 204 | 0.14 | 0.19-0.66 | 0 |
| goose-uring-rest | C | alone | poll | 933-934 of 935 | 0.10 | 0.40-0.52 | 0 |
| goose-uring-rest | C | alone | shifts | 153 of 153 | 0.12 | 0.16-0.17 | 0 |
| goose-uring | C | uploads | bookings | 153 of 153 | 2.48-2.65 | 5.50-7.20 | 0 |
| goose-uring | C | uploads | client | 51 of 51 | 2.28-2.29 | 6.06-7.12 | 0 |
| goose-uring | C | uploads | encounter | 204 of 204 | 2.29-2.58 | 6.24-7.92 | 0 |
| goose-uring | C | uploads | history | 204 of 204 | 1.96-2.35 | 4.95-6.36 | 0 |
| goose-uring | C | uploads | poll | 933-934 of 935 | 2.29-2.54 | 6.33-7.77 | 0 |
| goose-uring | C | uploads | shifts | 153 of 153 | 2.10-2.48 | 5.57-7.75 | 0 |
| goose-epoll | C | uploads | bookings | 153 of 153 | 0.75-0.77 | 1.22-1.34 | 0 |
| goose-epoll | C | uploads | client | 51 of 51 | 0.15-0.17 | 0.39-0.60 | 0 |
| goose-epoll | C | uploads | encounter | 204 of 204 | 0.16-0.19 | 0.47-1.01 | 0 |
| goose-epoll | C | uploads | history | 204 of 204 | 0.20 | 0.43-0.88 | 0 |
| goose-epoll | C | uploads | poll | 934 of 935 | 0.15-0.17 | 0.70-1.05 | 0 |
| goose-epoll | C | uploads | shifts | 153 of 153 | 0.17-0.18 | 0.41-0.55 | 0 |
| goose-epoll-rest | C | uploads | bookings | 153 of 153 | 0.75-0.78 | 1.21-1.26 | 0 |
| goose-epoll-rest | C | uploads | client | 51 of 51 | 0.19-0.23 | 0.46-1.03 | 0 |
| goose-epoll-rest | C | uploads | encounter | 204 of 204 | 0.19-0.20 | 0.51-0.95 | 0 |
| goose-epoll-rest | C | uploads | history | 204 of 204 | 0.22-0.23 | 0.63-0.97 | 0 |
| goose-epoll-rest | C | uploads | poll | 933-934 of 935 | 0.18 | 0.76-0.81 | 0 |
| goose-epoll-rest | C | uploads | shifts | 153 of 153 | 0.19 | 0.48-0.50 | 0 |
| goose-uring-rest | C | uploads | bookings | 153 of 153 | 2.33-2.93 | 6.19-6.70 | 0 |
| goose-uring-rest | C | uploads | client | 51 of 51 | 2.54-2.75 | 6.91-8.15 | 0 |
| goose-uring-rest | C | uploads | encounter | 204 of 204 | 2.55-2.91 | 7.52-8.37 | 0 |
| goose-uring-rest | C | uploads | history | 204 of 204 | 2.29-2.56 | 5.51-6.58 | 0 |
| goose-uring-rest | C | uploads | poll | 932-934 of 935 | 2.55-2.77 | 7.92-8.42 | 0 |
| goose-uring-rest | C | uploads | shifts | 153 of 153 | 2.24-2.77 | 6.54-7.95 | 0 |

| Server | Tier | Run | CPU µs/req | uploads/s |
|---|---|---|---:|---:|
| goose-uring | C | alone | 89.8-91.1 |  |
| goose-epoll | C | alone | 89.0-89.9 |  |
| goose-epoll-rest | C | alone | 89.9-90.7 |  |
| goose-uring-rest | C | alone | 89.4-92.7 |  |
| goose-uring | C | uploads | 2317.9-2323.2 | 1.1K |
| goose-epoll | C | uploads | 2309.1-2327.9 | 1.2K |
| goose-epoll-rest | C | uploads | 2349.6-2353.7 | 1.1K |
| goose-uring-rest | C | uploads | 2329.4-2357.9 | 1.1K |

