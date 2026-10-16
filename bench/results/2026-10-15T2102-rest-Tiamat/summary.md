## Saturation

| Server | Tier | JSON | req/s, median | range | p50 ms | p99 ms | CPU µs/req | peak RSS MB | errors |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|
| goose-uring | A | serialize | 600.3K | 596.1K-600.5K | 0.36 | 0.61 | 6.6 | 12 | 0 |
| goose-epoll | A | serialize | 453.9K | 453.0K-454.2K | 0.54 | 0.87 | 8.8 | 7 | 0 |
| goose-epoll-rest | A | serialize | 431.6K | 426.5K-433.6K | 0.57 | 0.88 | 9.3 | 8 | 0 |
| goose-uring-rest | A | serialize | 584.3K | 558.6K-591.1K | 0.37 | 0.64 | 6.8 | 13 | 0 |
| goose-uring | A | template | 607.0K | 591.6K-607.7K | 0.35 | 0.59 | 6.5 | 12 | 0 |
| goose-epoll | A | template | 472.5K | 468.1K-474.2K | 0.51 | 0.82 | 8.5 | 8 | 0 |
| goose-epoll-rest | A | template | 452.9K | 443.5K-453.3K | 0.54 | 0.91 | 8.8 | 8 | 0 |
| goose-uring-rest | A | template | 594.0K | 584.9K-603.0K | 0.36 | 0.62 | 6.6 | 12 | 0 |
| goose-uring | B | serialize | 318.2K | 316.0K-318.9K | 0.77 | 1.20 | 12.6 | 30 | 0 |
| goose-epoll | B | serialize | 242.6K | 240.0K-244.8K | 1.06 | 1.47 | 16.5 | 29 | 0 |
| goose-epoll-rest | B | serialize | 241.9K | 241.0K-245.5K | 1.06 | 1.54 | 16.6 | 30 | 0 |
| goose-uring-rest | B | serialize | 311.6K | 307.6K-312.7K | 0.79 | 1.24 | 12.8 | 32 | 0 |
| goose-uring | B | template | 390.9K | 389.6K-392.5K | 0.62 | 0.95 | 10.2 | 50 | 0 |
| goose-epoll | B | template | 293.9K | 282.1K-294.8K | 0.89 | 1.29 | 13.6 | 50 | 0 |
| goose-epoll-rest | B | template | 291.5K | 291.4K-294.3K | 0.85 | 1.25 | 13.7 | 47 | 0 |
| goose-uring-rest | B | template | 390.8K | 386.9K-391.3K | 0.63 | 0.94 | 10.2 | 49 | 0 |
| goose-uring | C | serialize | 62.0K | 60.5K-62.6K | 3.99 | 8.78 | 64.4 | 70 | 0 |
| goose-epoll | C | serialize | 60.9K | 54.7K-61.0K | 4.06 | 8.36 | 65.9 | 69 | 0 |
| goose-epoll-rest | C | serialize | 60.2K | 60.1K-60.2K | 4.11 | 8.42 | 66.7 | 71 | 0 |
| goose-uring-rest | C | serialize | 61.3K | 60.7K-61.6K | 4.08 | 8.99 | 65.1 | 72 | 0 |
| goose-uring | C | template | 144.9K | 144.5K-146.1K | 1.69 | 3.20 | 27.4 | 58 | 0 |
| goose-epoll | C | template | 135.4K | 122.4K-136.3K | 1.82 | 3.22 | 29.5 | 58 | 0 |
| goose-epoll-rest | C | template | 130.2K | 130.0K-130.6K | 1.91 | 3.13 | 30.7 | 58 | 0 |
| goose-uring-rest | C | template | 139.3K | 139.0K-141.2K | 1.75 | 3.43 | 28.6 | 58 | 0 |

## Tier D

| Server | Run | uploads/s | uploads p50 ms | forms role req/s | forms p99 ms | peak RSS MB | upload errors |
|---|---|---:|---:|---:|---:|---:|---:|
| goose-uring | alone | 1.1K | 16.7-17.7 |  |  | 70 | 0 |
| goose-epoll | alone | 1.1K | 15.2-16.0 |  |  | 69 | 0 |
| goose-epoll-rest | alone | 1.1K | 15.5-16.6 |  |  | 71 | 0 |
| goose-uring-rest | alone | 1.1K | 17.1-17.5 |  |  | 72 | 0 |
| goose-uring | beside forms | 157-184 | 110-140 | 7.2K-7.4K | 72.4-80.3 | 124 | 0 |
| goose-epoll | beside forms | 117-124 | 153-180 | 7.5K | 87.6-91.5 | 132 | 0 |
| goose-epoll-rest | beside forms | 122-129 | 153-165 | 7.7K-8.0K | 81.8-86.6 | 160 | 0 |
| goose-uring-rest | beside forms | 170-174 | 114-122 | 7.5K-7.6K | 68.5-73.6 | 133 | 0 |

## Fixed rate

| Server | Tier | Run | Route | rate reached | p50 ms | p99 ms | errors |
|---|---|---|---|---:|---:|---:|---:|
| goose-uring | A | serialize | item | 77.8K of 78.0K | 0.10 | 0.16-0.19 | 0 |
| goose-uring | A | serialize | me | 16.0K of 16.0K | 0.09 | 0.15-0.17 | 0 |
| goose-uring | A | serialize | write | 6.0K of 6.0K | 0.11 | 0.16-0.19 | 0 |
| goose-epoll | A | serialize | item | 77.7K-77.8K of 78.0K | 0.10 | 0.16-0.17 | 0 |
| goose-epoll | A | serialize | me | 16.0K of 16.0K | 0.09 | 0.16 | 0 |
| goose-epoll | A | serialize | write | 6.0K of 6.0K | 0.10-0.11 | 0.16-0.17 | 0 |
| goose-epoll-rest | A | serialize | item | 77.8K of 78.0K | 0.10 | 0.16-0.17 | 0 |
| goose-epoll-rest | A | serialize | me | 16.0K of 16.0K | 0.09 | 0.16 | 0 |
| goose-epoll-rest | A | serialize | write | 6.0K of 6.0K | 0.11 | 0.16-0.17 | 0 |
| goose-uring-rest | A | serialize | item | 77.8K-77.9K of 78.0K | 0.10 | 0.16 | 0 |
| goose-uring-rest | A | serialize | me | 16.0K of 16.0K | 0.09 | 0.15-0.16 | 0 |
| goose-uring-rest | A | serialize | write | 6.0K of 6.0K | 0.11 | 0.16-0.17 | 0 |
| goose-uring | A | template | item | 77.8K of 78.0K | 0.10 | 0.16-0.17 | 0 |
| goose-uring | A | template | me | 16.0K of 16.0K | 0.09 | 0.15-0.16 | 0 |
| goose-uring | A | template | write | 6.0K of 6.0K | 0.10-0.11 | 0.16-0.17 | 0 |
| goose-epoll | A | template | item | 77.8K-77.9K of 78.0K | 0.10 | 0.16 | 0 |
| goose-epoll | A | template | me | 16.0K of 16.0K | 0.09 | 0.16 | 0 |
| goose-epoll | A | template | write | 6.0K of 6.0K | 0.11 | 0.17 | 0 |
| goose-epoll-rest | A | template | item | 77.8K of 78.0K | 0.10 | 0.16-0.20 | 0 |
| goose-epoll-rest | A | template | me | 16.0K of 16.0K | 0.09 | 0.16-0.18 | 0 |
| goose-epoll-rest | A | template | write | 6.0K of 6.0K | 0.11 | 0.16-0.19 | 0 |
| goose-uring-rest | A | template | item | 77.8K-77.9K of 78.0K | 0.10 | 0.16 | 0 |
| goose-uring-rest | A | template | me | 16.0K of 16.0K | 0.09 | 0.15-0.16 | 0 |
| goose-uring-rest | A | template | write | 6.0K of 6.0K | 0.11 | 0.16 | 0 |
| goose-uring | B | serialize | entries | 6.0K of 6.0K | 0.10-0.11 | 0.15-0.16 | 0 |
| goose-uring | B | serialize | patch | 2.4K of 2.4K | 0.10 | 0.14-0.15 | 0 |
| goose-uring | B | serialize | projects | 3.6K of 3.6K | 0.10 | 0.14-0.15 | 0 |
| goose-uring | B | serialize | session | 6.0K of 6.0K | 0.10 | 0.14-0.15 | 0 |
| goose-uring | B | serialize | timer | 6.0K of 6.0K | 0.10 | 0.14-0.15 | 0 |
| goose-epoll | B | serialize | entries | 6.0K of 6.0K | 0.10-0.11 | 0.14-0.15 | 0 |
| goose-epoll | B | serialize | patch | 2.4K of 2.4K | 0.10 | 0.14 | 0 |
| goose-epoll | B | serialize | projects | 3.6K of 3.6K | 0.10 | 0.14 | 0 |
| goose-epoll | B | serialize | session | 6.0K of 6.0K | 0.10 | 0.14 | 0 |
| goose-epoll | B | serialize | timer | 6.0K of 6.0K | 0.10 | 0.13-0.14 | 0 |
| goose-epoll-rest | B | serialize | entries | 6.0K of 6.0K | 0.10-0.11 | 0.15 | 0 |
| goose-epoll-rest | B | serialize | patch | 2.4K of 2.4K | 0.10 | 0.14 | 0 |
| goose-epoll-rest | B | serialize | projects | 3.6K of 3.6K | 0.10 | 0.14 | 0 |
| goose-epoll-rest | B | serialize | session | 6.0K of 6.0K | 0.10 | 0.14-0.15 | 0 |
| goose-epoll-rest | B | serialize | timer | 6.0K of 6.0K | 0.10 | 0.13-0.14 | 0 |
| goose-uring-rest | B | serialize | entries | 6.0K of 6.0K | 0.11 | 0.15-0.18 | 0 |
| goose-uring-rest | B | serialize | patch | 2.4K of 2.4K | 0.10 | 0.14-0.15 | 0 |
| goose-uring-rest | B | serialize | projects | 3.6K of 3.6K | 0.10 | 0.14-0.15 | 0 |
| goose-uring-rest | B | serialize | session | 6.0K of 6.0K | 0.10 | 0.14-0.16 | 0 |
| goose-uring-rest | B | serialize | timer | 6.0K of 6.0K | 0.10 | 0.14-0.16 | 0 |
| goose-uring | B | template | entries | 6.0K of 6.0K | 0.10 | 0.14-0.16 | 0 |
| goose-uring | B | template | patch | 2.4K of 2.4K | 0.10 | 0.14 | 0 |
| goose-uring | B | template | projects | 3.6K of 3.6K | 0.10 | 0.14 | 0 |
| goose-uring | B | template | session | 6.0K of 6.0K | 0.09-0.10 | 0.14-0.15 | 0 |
| goose-uring | B | template | timer | 6.0K of 6.0K | 0.10 | 0.13-0.14 | 0 |
| goose-epoll | B | template | entries | 6.0K of 6.0K | 0.10 | 0.14-1.31 | 0 |
| goose-epoll | B | template | patch | 2.4K of 2.4K | 0.10 | 0.14-0.32 | 0 |
| goose-epoll | B | template | projects | 3.6K of 3.6K | 0.10 | 0.14-0.77 | 0 |
| goose-epoll | B | template | session | 6.0K of 6.0K | 0.10 | 0.14-0.60 | 0 |
| goose-epoll | B | template | timer | 6.0K of 6.0K | 0.09-0.10 | 0.13-3.86 | 0 |
| goose-epoll-rest | B | template | entries | 6.0K of 6.0K | 0.10 | 0.14-0.15 | 0 |
| goose-epoll-rest | B | template | patch | 2.4K of 2.4K | 0.10 | 0.14 | 0 |
| goose-epoll-rest | B | template | projects | 3.6K of 3.6K | 0.10 | 0.14 | 0 |
| goose-epoll-rest | B | template | session | 6.0K of 6.0K | 0.10 | 0.13-0.14 | 0 |
| goose-epoll-rest | B | template | timer | 6.0K of 6.0K | 0.10 | 0.13-0.14 | 0 |
| goose-uring-rest | B | template | entries | 6.0K of 6.0K | 0.10 | 0.14-0.15 | 0 |
| goose-uring-rest | B | template | patch | 2.4K of 2.4K | 0.10 | 0.14-0.15 | 0 |
| goose-uring-rest | B | template | projects | 3.6K of 3.6K | 0.10 | 0.14-0.15 | 0 |
| goose-uring-rest | B | template | session | 6.0K of 6.0K | 0.10 | 0.14 | 0 |
| goose-uring-rest | B | template | timer | 6.0K of 6.0K | 0.10 | 0.14 | 0 |
| goose-uring | C | serialize | bookings | 153 of 153 | 0.68-0.69 | 0.83-0.94 | 0 |
| goose-uring | C | serialize | client | 51 of 51 | 0.10-0.11 | 0.14-0.17 | 0 |
| goose-uring | C | serialize | encounter | 204 of 204 | 0.11-0.12 | 0.17-0.20 | 0 |
| goose-uring | C | serialize | history | 204 of 204 | 0.14-0.15 | 0.20-0.27 | 0 |
| goose-uring | C | serialize | poll | 934 of 935 | 0.10 | 0.47-0.49 | 0 |
| goose-uring | C | serialize | shifts | 153 of 153 | 0.11-0.12 | 0.17-0.19 | 0 |
| goose-epoll | C | serialize | bookings | 153 of 153 | 0.67-0.70 | 0.85-0.91 | 0 |
| goose-epoll | C | serialize | client | 51 of 51 | 0.11 | 0.16-0.20 | 0 |
| goose-epoll | C | serialize | encounter | 204 of 204 | 0.12 | 0.17-0.21 | 0 |
| goose-epoll | C | serialize | history | 204 of 204 | 0.14 | 0.20-0.26 | 0 |
| goose-epoll | C | serialize | poll | 933-934 of 935 | 0.10 | 0.51-0.53 | 0 |
| goose-epoll | C | serialize | shifts | 153 of 153 | 0.11-0.12 | 0.16-0.20 | 0 |
| goose-epoll-rest | C | serialize | bookings | 153 of 153 | 0.67-0.68 | 0.83-0.84 | 0 |
| goose-epoll-rest | C | serialize | client | 51 of 51 | 0.10-0.11 | 0.15-0.16 | 0 |
| goose-epoll-rest | C | serialize | encounter | 204 of 204 | 0.12 | 0.20-0.38 | 0 |
| goose-epoll-rest | C | serialize | history | 204 of 204 | 0.14-0.15 | 0.20-0.24 | 0 |
| goose-epoll-rest | C | serialize | poll | 933-934 of 935 | 0.10 | 0.48-0.49 | 0 |
| goose-epoll-rest | C | serialize | shifts | 153 of 153 | 0.11-0.12 | 0.16-0.18 | 0 |
| goose-uring-rest | C | serialize | bookings | 153 of 153 | 0.67-0.69 | 0.85-0.91 | 0 |
| goose-uring-rest | C | serialize | client | 51 of 51 | 0.11-0.12 | 0.15-0.18 | 0 |
| goose-uring-rest | C | serialize | encounter | 204 of 204 | 0.12-0.13 | 0.18-0.31 | 0 |
| goose-uring-rest | C | serialize | history | 204 of 204 | 0.14 | 0.28-0.31 | 0 |
| goose-uring-rest | C | serialize | poll | 933-934 of 935 | 0.10 | 0.49-0.51 | 0 |
| goose-uring-rest | C | serialize | shifts | 153 of 153 | 0.12 | 0.16-0.22 | 0 |
| goose-uring | C | template | bookings | 153 of 153 | 0.29-0.30 | 0.45-0.48 | 0 |
| goose-uring | C | template | client | 51 of 51 | 0.10-0.11 | 0.15-0.16 | 0 |
| goose-uring | C | template | encounter | 204 of 204 | 0.12 | 0.17 | 0 |
| goose-uring | C | template | history | 204 of 204 | 0.13-0.14 | 0.18-0.25 | 0 |
| goose-uring | C | template | poll | 932-934 of 935 | 0.10 | 0.17-0.19 | 0 |
| goose-uring | C | template | shifts | 153 of 153 | 0.10-0.11 | 0.14-0.15 | 0 |
| goose-epoll | C | template | bookings | 153 of 153 | 0.29-0.30 | 0.43-0.46 | 0 |
| goose-epoll | C | template | client | 51 of 51 | 0.10-0.11 | 0.15 | 0 |
| goose-epoll | C | template | encounter | 204 of 204 | 0.11-0.12 | 0.16 | 0 |
| goose-epoll | C | template | history | 204 of 204 | 0.12-0.13 | 0.18 | 0 |
| goose-epoll | C | template | poll | 933-934 of 935 | 0.10 | 0.17-0.18 | 0 |
| goose-epoll | C | template | shifts | 153 of 153 | 0.10-0.11 | 0.15 | 0 |
| goose-epoll-rest | C | template | bookings | 153 of 153 | 0.29-0.30 | 0.42-0.45 | 0 |
| goose-epoll-rest | C | template | client | 51 of 51 | 0.11-0.12 | 0.16-0.18 | 0 |
| goose-epoll-rest | C | template | encounter | 204 of 204 | 0.12 | 0.17 | 0 |
| goose-epoll-rest | C | template | history | 204 of 204 | 0.13 | 0.18-0.26 | 0 |
| goose-epoll-rest | C | template | poll | 933-934 of 935 | 0.10 | 0.17-0.18 | 0 |
| goose-epoll-rest | C | template | shifts | 153 of 153 | 0.10-0.11 | 0.15-0.16 | 0 |
| goose-uring-rest | C | template | bookings | 153 of 153 | 0.29 | 0.43-0.45 | 0 |
| goose-uring-rest | C | template | client | 51 of 51 | 0.10-0.12 | 0.15-0.17 | 0 |
| goose-uring-rest | C | template | encounter | 204 of 204 | 0.12 | 0.16-0.17 | 0 |
| goose-uring-rest | C | template | history | 204 of 204 | 0.13 | 0.18-0.22 | 0 |
| goose-uring-rest | C | template | poll | 933-934 of 935 | 0.10 | 0.17-0.19 | 0 |
| goose-uring-rest | C | template | shifts | 153 of 153 | 0.11-0.12 | 0.15-0.17 | 0 |

| Server | Tier | Run | CPU µs/req | uploads/s |
|---|---|---|---:|---:|
| goose-uring | A | serialize | 20.7-21.3 |  |
| goose-epoll | A | serialize | 20.3-21.2 |  |
| goose-epoll-rest | A | serialize | 20.5-21.9 |  |
| goose-uring-rest | A | serialize | 21.0-22.1 |  |
| goose-uring | A | template | 20.4-20.9 |  |
| goose-epoll | A | template | 20.8-21.1 |  |
| goose-epoll-rest | A | template | 21.1-21.3 |  |
| goose-uring-rest | A | template | 21.0-21.4 |  |
| goose-uring | B | serialize | 32.5-32.8 |  |
| goose-epoll | B | serialize | 32.2-32.7 |  |
| goose-epoll-rest | B | serialize | 32.3-32.8 |  |
| goose-uring-rest | B | serialize | 32.7-33.3 |  |
| goose-uring | B | template | 31.2-31.3 |  |
| goose-epoll | B | template | 30.2-32.0 |  |
| goose-epoll-rest | B | template | 30.9-31.5 |  |
| goose-uring-rest | B | template | 31.0-31.9 |  |
| goose-uring | C | serialize | 91.4-92.6 |  |
| goose-epoll | C | serialize | 91.0-91.9 |  |
| goose-epoll-rest | C | serialize | 91.5-93.0 |  |
| goose-uring-rest | C | serialize | 92.3-93.4 |  |
| goose-uring | C | template | 54.2-54.6 |  |
| goose-epoll | C | template | 52.6-53.4 |  |
| goose-epoll-rest | C | template | 54.9-56.9 |  |
| goose-uring-rest | C | template | 54.6-56.1 |  |

## Mixed run: tier C's reads, alone and beside uploads

| Server | Tier | Run | Route | rate reached | p50 ms | p99 ms | errors |
|---|---|---|---|---:|---:|---:|---:|
| goose-uring | C | alone | bookings | 153 of 153 | 0.68-0.69 | 0.85-0.86 | 0 |
| goose-uring | C | alone | client | 51 of 51 | 0.11 | 0.16 | 0 |
| goose-uring | C | alone | encounter | 204 of 204 | 0.12 | 0.17-0.53 | 0 |
| goose-uring | C | alone | history | 204 of 204 | 0.14-0.15 | 0.21-0.51 | 0 |
| goose-uring | C | alone | poll | 933-934 of 935 | 0.10-0.11 | 0.42-0.50 | 0 |
| goose-uring | C | alone | shifts | 153 of 153 | 0.12-0.13 | 0.17-0.18 | 0 |
| goose-epoll | C | alone | bookings | 153 of 153 | 0.69-0.71 | 0.85-0.87 | 0 |
| goose-epoll | C | alone | client | 51 of 51 | 0.10-0.11 | 0.15 | 0 |
| goose-epoll | C | alone | encounter | 204 of 204 | 0.12 | 0.24-0.67 | 0 |
| goose-epoll | C | alone | history | 204 of 204 | 0.14-0.15 | 0.20-0.73 | 0 |
| goose-epoll | C | alone | poll | 933-934 of 935 | 0.10 | 0.45-0.52 | 0 |
| goose-epoll | C | alone | shifts | 153 of 153 | 0.11-0.12 | 0.15-0.17 | 0 |
| goose-epoll-rest | C | alone | bookings | 153 of 153 | 0.68-0.70 | 0.85-0.87 | 0 |
| goose-epoll-rest | C | alone | client | 51 of 51 | 0.11 | 0.16 | 0 |
| goose-epoll-rest | C | alone | encounter | 204 of 204 | 0.12 | 0.17-0.38 | 0 |
| goose-epoll-rest | C | alone | history | 204 of 204 | 0.14 | 0.20-0.34 | 0 |
| goose-epoll-rest | C | alone | poll | 934 of 935 | 0.10 | 0.48-0.49 | 0 |
| goose-epoll-rest | C | alone | shifts | 153 of 153 | 0.11-0.12 | 0.16-0.17 | 0 |
| goose-uring-rest | C | alone | bookings | 153 of 153 | 0.68-0.69 | 0.84-0.87 | 0 |
| goose-uring-rest | C | alone | client | 51 of 51 | 0.10-0.11 | 0.14-0.16 | 0 |
| goose-uring-rest | C | alone | encounter | 204 of 204 | 0.12-0.13 | 0.22-0.34 | 0 |
| goose-uring-rest | C | alone | history | 204 of 204 | 0.14-0.15 | 0.22-0.58 | 0 |
| goose-uring-rest | C | alone | poll | 933-934 of 935 | 0.10 | 0.46-0.50 | 0 |
| goose-uring-rest | C | alone | shifts | 153 of 153 | 0.11-0.12 | 0.16-0.17 | 0 |
| goose-uring | C | uploads | bookings | 153 of 153 | 2.22-2.57 | 6.15-7.71 | 0 |
| goose-uring | C | uploads | client | 51 of 51 | 2.12-2.64 | 6.59-8.80 | 0 |
| goose-uring | C | uploads | encounter | 204 of 204 | 1.94-2.12 | 6.27-8.24 | 0 |
| goose-uring | C | uploads | history | 204 of 204 | 1.47-2.28 | 5.52-6.22 | 0 |
| goose-uring | C | uploads | poll | 933-934 of 935 | 2.01-2.58 | 7.35-8.34 | 0 |
| goose-uring | C | uploads | shifts | 153 of 153 | 2.13-2.29 | 6.70-8.05 | 0 |
| goose-epoll | C | uploads | bookings | 153 of 153 | 0.76-0.78 | 1.22-1.42 | 0 |
| goose-epoll | C | uploads | client | 51 of 51 | 0.16-0.17 | 0.44-0.59 | 0 |
| goose-epoll | C | uploads | encounter | 204 of 204 | 0.17-0.18 | 0.70-0.84 | 0 |
| goose-epoll | C | uploads | history | 204 of 204 | 0.20-0.22 | 0.56-0.70 | 0 |
| goose-epoll | C | uploads | poll | 933-934 of 935 | 0.15-0.17 | 0.76-2.78 | 0 |
| goose-epoll | C | uploads | shifts | 153 of 153 | 0.17-0.19 | 0.44-0.61 | 0 |
| goose-epoll-rest | C | uploads | bookings | 153 of 153 | 0.77-0.79 | 1.33-1.37 | 0 |
| goose-epoll-rest | C | uploads | client | 51 of 51 | 0.17-0.18 | 0.51-0.53 | 0 |
| goose-epoll-rest | C | uploads | encounter | 204 of 204 | 0.18-0.21 | 0.80-0.88 | 0 |
| goose-epoll-rest | C | uploads | history | 204 of 204 | 0.21-0.23 | 0.62-1.13 | 0 |
| goose-epoll-rest | C | uploads | poll | 933-934 of 935 | 0.17-0.18 | 0.81-1.06 | 0 |
| goose-epoll-rest | C | uploads | shifts | 153 of 153 | 0.17-0.19 | 0.53-0.59 | 0 |
| goose-uring-rest | C | uploads | bookings | 153 of 153 | 2.58-2.87 | 7.13-7.59 | 0 |
| goose-uring-rest | C | uploads | client | 51 of 51 | 2.25-2.47 | 7.58-8.05 | 0 |
| goose-uring-rest | C | uploads | encounter | 204 of 204 | 2.33-2.91 | 7.79-8.52 | 0 |
| goose-uring-rest | C | uploads | history | 204 of 204 | 1.90-2.21 | 5.92-6.85 | 0 |
| goose-uring-rest | C | uploads | poll | 933-934 of 935 | 2.50-2.69 | 8.44-8.73 | 0 |
| goose-uring-rest | C | uploads | shifts | 153 of 153 | 2.54-3.31 | 7.70-8.52 | 0 |

| Server | Tier | Run | CPU µs/req | uploads/s |
|---|---|---|---:|---:|
| goose-uring | C | alone | 92.2-93.8 |  |
| goose-epoll | C | alone | 92.2-92.3 |  |
| goose-epoll-rest | C | alone | 91.8-93.4 |  |
| goose-uring-rest | C | alone | 92.2-92.6 |  |
| goose-uring | C | uploads | 2247.6-2303.4 | 1.1K |
| goose-epoll | C | uploads | 2291.1-2308.4 | 1.1K |
| goose-epoll-rest | C | uploads | 2317.8-2337.2 | 1.1K |
| goose-uring-rest | C | uploads | 2289.6-2327.9 | 1.1K |

