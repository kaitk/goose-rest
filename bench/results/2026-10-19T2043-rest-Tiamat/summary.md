## Saturation

| Server | Tier | JSON | req/s, median | range | p50 ms | p99 ms | CPU µs/req | peak RSS MB | errors |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|
| goose-uring | A | serialize | 601.1K | 597.7K-602.1K | 0.36 | 0.66 | 6.6 | 13 | 0 |
| goose-epoll | A | serialize | 452.9K | 441.8K-453.2K | 0.55 | 0.85 | 8.8 | 8 | 0 |
| aegon | A | serialize | 513.0K | 495.8K-513.9K | 0.48 | 0.75 | 7.8 | 282 | 0 |
| aegon-small | A | serialize | 510.5K | 506.2K-513.7K | 0.48 | 0.75 | 7.8 | 27 | 0 |
| goose-epoll-rest | A | serialize | 431.8K | 429.5K-432.6K | 0.58 | 0.97 | 9.3 | 8 | 0 |
| goose-uring-rest | A | serialize | 593.6K | 592.1K-596.1K | 0.37 | 0.63 | 6.7 | 13 | 0 |
| goose-uring | A | template | 608.8K | 601.9K-615.5K | 0.35 | 0.61 | 6.5 | 12 | 0 |
| goose-epoll | A | template | 456.5K | 441.3K-464.4K | 0.54 | 0.84 | 8.8 | 8 | 0 |
| aegon | A | template | 524.5K | 522.9K-530.5K | 0.47 | 0.70 | 7.6 | 288 | 0 |
| aegon-small | A | template | 527.3K | 525.1K-529.8K | 0.45 | 0.77 | 7.6 | 31 | 0 |
| goose-epoll-rest | A | template | 448.9K | 446.2K-450.1K | 0.53 | 0.91 | 8.9 | 8 | 0 |
| goose-uring-rest | A | template | 603.6K | 600.0K-604.3K | 0.36 | 0.62 | 6.6 | 12 | 0 |
| goose-uring | B | serialize | 318.7K | 318.5K-319.4K | 0.78 | 1.18 | 12.5 | 30 | 0 |
| goose-epoll | B | serialize | 246.9K | 241.6K-249.7K | 1.04 | 1.59 | 16.3 | 29 | 0 |
| aegon | B | serialize | 287.3K | 284.6K-291.0K | 0.87 | 1.24 | 13.9 | 312 | 0 |
| aegon-small | B | serialize | 290.4K | 287.7K-292.8K | 0.87 | 1.21 | 13.8 | 59 | 0 |
| goose-epoll-rest | B | serialize | 244.7K | 240.1K-246.0K | 1.04 | 1.53 | 16.4 | 29 | 0 |
| goose-uring-rest | B | serialize | 319.4K | 318.4K-320.8K | 0.77 | 1.21 | 12.5 | 31 | 0 |
| goose-uring | B | template | 399.4K | 397.0K-399.7K | 0.61 | 0.95 | 10.0 | 50 | 0 |
| goose-epoll | B | template | 302.8K | 291.3K-303.6K | 0.82 | 1.28 | 13.2 | 50 | 0 |
| aegon | B | template | 347.0K | 343.8K-348.2K | 0.72 | 1.06 | 11.5 | 355 | 0 |
| aegon-small | B | template | 348.5K | 345.9K-348.6K | 0.73 | 1.04 | 11.5 | 98 | 0 |
| goose-epoll-rest | B | template | 298.6K | 298.6K-302.6K | 0.86 | 1.26 | 13.4 | 50 | 0 |
| goose-uring-rest | B | template | 397.8K | 394.2K-400.2K | 0.62 | 0.96 | 10.0 | 50 | 0 |
| goose-uring | C | serialize | 64.1K | 63.9K-64.1K | 3.87 | 8.38 | 62.4 | 71 | 0 |
| goose-epoll | C | serialize | 61.9K | 61.4K-62.5K | 3.98 | 8.12 | 64.8 | 69 | 0 |
| aegon | C | serialize | 54.0K | 53.9K-54.4K | 4.54 | 9.67 | 73.9 | 578 | 0 |
| aegon-small | C | serialize | 54.0K | 53.9K-54.1K | 4.57 | 9.21 | 73.9 | 321 | 0 |
| goose-epoll-rest | C | serialize | 61.0K | 60.4K-61.6K | 4.07 | 7.93 | 65.8 | 69 | 0 |
| goose-uring-rest | C | serialize | 62.2K | 62.1K-62.3K | 3.99 | 8.62 | 64.3 | 71 | 0 |
| goose-uring | C | template | 153.1K | 152.0K-153.3K | 1.60 | 3.04 | 26.0 | 58 | 0 |
| goose-epoll | C | template | 144.3K | 143.0K-144.4K | 1.72 | 2.90 | 27.7 | 58 | 0 |
| aegon | C | template | 116.9K | 116.5K-117.9K | 2.08 | 4.14 | 33.8 | 644 | 0 |
| aegon-small | C | template | 117.8K | 117.5K-118.5K | 2.08 | 3.85 | 33.6 | 388 | 0 |
| goose-epoll-rest | C | template | 132.2K | 128.9K-132.9K | 1.88 | 3.21 | 30.3 | 58 | 0 |
| goose-uring-rest | C | template | 142.2K | 142.1K-142.9K | 1.72 | 3.21 | 28.0 | 58 | 0 |

## Tier D

| Server | Run | uploads/s | uploads p50 ms | forms role req/s | forms p99 ms | peak RSS MB | upload errors |
|---|---|---:|---:|---:|---:|---:|---:|
| goose-uring | alone | 1.2K | 15.9-16.2 |  |  | 71 | 0 |
| goose-epoll | alone | 1.2K | 14.3-15.6 |  |  | 69 | 0 |
| goose-epoll-rest | alone | 1.1K-1.2K | 16.3-18.6 |  |  | 69 | 0 |
| goose-uring-rest | alone | 1.1K-1.2K | 16.1-17.0 |  |  | 71 | 0 |
| goose-uring | beside forms | 164-173 | 122-128 | 7.5K-7.6K | 68.4-72.8 | 126 | 0 |
| goose-epoll | beside forms | 120-122 | 160-199 | 7.7K-7.8K | 83.0-87.9 | 132 | 0 |
| goose-epoll-rest | beside forms | 106-111 | 172-184 | 6.8K-7.0K | 91.7-101 | 149 | 0 |
| goose-uring-rest | beside forms | 147-154 | 128-139 | 6.5K-6.6K | 78.3-83.0 | 123 | 0 |

## Fixed rate

| Server | Tier | Run | Route | rate reached | p50 ms | p99 ms | errors |
|---|---|---|---|---:|---:|---:|---:|
| goose-uring | A | serialize | item | 77.8K-77.9K of 78.0K | 0.09-0.10 | 0.16 | 0 |
| goose-uring | A | serialize | me | 16.0K of 16.0K | 0.09 | 0.15-0.16 | 0 |
| goose-uring | A | serialize | write | 6.0K of 6.0K | 0.11 | 0.16-0.17 | 0 |
| goose-epoll | A | serialize | item | 77.7K-77.8K of 78.0K | 0.10 | 0.17-9.46 | 0 |
| goose-epoll | A | serialize | me | 16.0K of 16.0K | 0.09 | 0.16-14.9 | 0 |
| goose-epoll | A | serialize | write | 6.0K of 6.0K | 0.11 | 0.16-11.3 | 0 |
| aegon | A | serialize | item | 77.8K of 78.0K | 0.10 | 0.17-0.18 | 0 |
| aegon | A | serialize | me | 16.0K of 16.0K | 0.10 | 0.16-0.17 | 0 |
| aegon | A | serialize | write | 6.0K of 6.0K | 0.11 | 0.17-0.18 | 0 |
| aegon-small | A | serialize | item | 77.8K of 78.0K | 0.10 | 0.18-2.44 | 0 |
| aegon-small | A | serialize | me | 16.0K of 16.0K | 0.10 | 0.17-1.63 | 0 |
| aegon-small | A | serialize | write | 6.0K of 6.0K | 0.11 | 0.18-0.90 | 0 |
| goose-epoll-rest | A | serialize | item | 77.8K of 78.0K | 0.10 | 0.16-0.20 | 0 |
| goose-epoll-rest | A | serialize | me | 16.0K of 16.0K | 0.09 | 0.16-0.19 | 0 |
| goose-epoll-rest | A | serialize | write | 6.0K of 6.0K | 0.11 | 0.17-0.19 | 0 |
| goose-uring-rest | A | serialize | item | 77.8K-77.9K of 78.0K | 0.10 | 0.16-1.88 | 0 |
| goose-uring-rest | A | serialize | me | 16.0K of 16.0K | 0.09-0.10 | 0.16-2.08 | 0 |
| goose-uring-rest | A | serialize | write | 6.0K of 6.0K | 0.11 | 0.16-0.69 | 0 |
| goose-uring | A | template | item | 77.7K-77.8K of 78.0K | 0.09-0.10 | 0.16 | 0 |
| goose-uring | A | template | me | 16.0K of 16.0K | 0.09 | 0.15-0.16 | 0 |
| goose-uring | A | template | write | 6.0K of 6.0K | 0.10-0.11 | 0.16 | 0 |
| goose-epoll | A | template | item | 77.8K of 78.0K | 0.09-0.10 | 0.16 | 0 |
| goose-epoll | A | template | me | 16.0K of 16.0K | 0.09 | 0.16 | 0 |
| goose-epoll | A | template | write | 6.0K of 6.0K | 0.10-0.11 | 0.16 | 0 |
| aegon | A | template | item | 77.8K-77.9K of 78.0K | 0.10 | 0.17-1.55 | 0 |
| aegon | A | template | me | 16.0K of 16.0K | 0.10 | 0.17-1.77 | 0 |
| aegon | A | template | write | 6.0K of 6.0K | 0.11 | 0.17-1.67 | 0 |
| aegon-small | A | template | item | 77.8K of 78.0K | 0.10 | 0.17 | 0 |
| aegon-small | A | template | me | 16.0K of 16.0K | 0.10 | 0.17 | 0 |
| aegon-small | A | template | write | 6.0K of 6.0K | 0.11 | 0.17-0.18 | 0 |
| goose-epoll-rest | A | template | item | 77.7K-77.9K of 78.0K | 0.10 | 0.16-4.84 | 0 |
| goose-epoll-rest | A | template | me | 16.0K of 16.0K | 0.09 | 0.16-9.11 | 0 |
| goose-epoll-rest | A | template | write | 6.0K of 6.0K | 0.11 | 0.16-1.37 | 0 |
| goose-uring-rest | A | template | item | 77.8K-77.9K of 78.0K | 0.10 | 0.17-1.24 | 0 |
| goose-uring-rest | A | template | me | 16.0K of 16.0K | 0.09 | 0.16-0.81 | 0 |
| goose-uring-rest | A | template | write | 6.0K of 6.0K | 0.11 | 0.16-0.33 | 0 |
| goose-uring | B | serialize | entries | 6.0K of 6.0K | 0.10-0.11 | 0.14-0.16 | 0 |
| goose-uring | B | serialize | patch | 2.4K of 2.4K | 0.10 | 0.14 | 0 |
| goose-uring | B | serialize | projects | 3.6K of 3.6K | 0.10 | 0.14-0.15 | 0 |
| goose-uring | B | serialize | session | 6.0K of 6.0K | 0.10 | 0.14-0.15 | 0 |
| goose-uring | B | serialize | timer | 6.0K of 6.0K | 0.10 | 0.14 | 0 |
| goose-epoll | B | serialize | entries | 6.0K of 6.0K | 0.10 | 0.14-0.15 | 0 |
| goose-epoll | B | serialize | patch | 2.4K of 2.4K | 0.10 | 0.14 | 0 |
| goose-epoll | B | serialize | projects | 3.6K of 3.6K | 0.10 | 0.14 | 0 |
| goose-epoll | B | serialize | session | 6.0K of 6.0K | 0.10 | 0.13-0.14 | 0 |
| goose-epoll | B | serialize | timer | 6.0K of 6.0K | 0.09-0.10 | 0.13-0.14 | 0 |
| aegon | B | serialize | entries | 6.0K of 6.0K | 0.11 | 0.15-0.16 | 0 |
| aegon | B | serialize | patch | 2.4K of 2.4K | 0.11 | 0.15 | 0 |
| aegon | B | serialize | projects | 3.6K of 3.6K | 0.10 | 0.15 | 0 |
| aegon | B | serialize | session | 6.0K of 6.0K | 0.10 | 0.14-0.15 | 0 |
| aegon | B | serialize | timer | 6.0K of 6.0K | 0.10 | 0.14-0.15 | 0 |
| aegon-small | B | serialize | entries | 6.0K of 6.0K | 0.11 | 0.16-0.18 | 0 |
| aegon-small | B | serialize | patch | 2.4K of 2.4K | 0.11 | 0.15-0.17 | 0 |
| aegon-small | B | serialize | projects | 3.6K of 3.6K | 0.10-0.11 | 0.15-0.17 | 0 |
| aegon-small | B | serialize | session | 6.0K of 6.0K | 0.10 | 0.14-0.15 | 0 |
| aegon-small | B | serialize | timer | 6.0K of 6.0K | 0.10 | 0.15-0.16 | 0 |
| goose-epoll-rest | B | serialize | entries | 6.0K of 6.0K | 0.10 | 0.14-0.15 | 0 |
| goose-epoll-rest | B | serialize | patch | 2.4K of 2.4K | 0.10 | 0.14-0.15 | 0 |
| goose-epoll-rest | B | serialize | projects | 3.6K of 3.6K | 0.10 | 0.14-0.15 | 0 |
| goose-epoll-rest | B | serialize | session | 6.0K of 6.0K | 0.10 | 0.14 | 0 |
| goose-epoll-rest | B | serialize | timer | 6.0K of 6.0K | 0.09-0.10 | 0.13-0.15 | 0 |
| goose-uring-rest | B | serialize | entries | 6.0K of 6.0K | 0.11 | 0.15-0.17 | 0 |
| goose-uring-rest | B | serialize | patch | 2.4K of 2.4K | 0.10 | 0.14-0.16 | 0 |
| goose-uring-rest | B | serialize | projects | 3.6K of 3.6K | 0.10 | 0.14-0.16 | 0 |
| goose-uring-rest | B | serialize | session | 6.0K of 6.0K | 0.10 | 0.14-0.16 | 0 |
| goose-uring-rest | B | serialize | timer | 6.0K of 6.0K | 0.10 | 0.14-0.16 | 0 |
| goose-uring | B | template | entries | 6.0K of 6.0K | 0.10-0.11 | 0.14-0.17 | 0 |
| goose-uring | B | template | patch | 2.4K of 2.4K | 0.10 | 0.14-0.16 | 0 |
| goose-uring | B | template | projects | 3.6K of 3.6K | 0.10 | 0.14-0.16 | 0 |
| goose-uring | B | template | session | 6.0K of 6.0K | 0.10 | 0.13-0.16 | 0 |
| goose-uring | B | template | timer | 6.0K of 6.0K | 0.10 | 0.13-0.16 | 0 |
| goose-epoll | B | template | entries | 6.0K of 6.0K | 0.10 | 0.14 | 0 |
| goose-epoll | B | template | patch | 2.4K of 2.4K | 0.10 | 0.14 | 0 |
| goose-epoll | B | template | projects | 3.6K of 3.6K | 0.10 | 0.13-0.14 | 0 |
| goose-epoll | B | template | session | 6.0K of 6.0K | 0.10 | 0.13-0.14 | 0 |
| goose-epoll | B | template | timer | 6.0K of 6.0K | 0.09-0.10 | 0.13-0.14 | 0 |
| aegon | B | template | entries | 6.0K of 6.0K | 0.10-0.11 | 0.15 | 0 |
| aegon | B | template | patch | 2.4K of 2.4K | 0.10-0.11 | 0.15 | 0 |
| aegon | B | template | projects | 3.6K of 3.6K | 0.10 | 0.14-0.15 | 0 |
| aegon | B | template | session | 6.0K of 6.0K | 0.10 | 0.14 | 0 |
| aegon | B | template | timer | 6.0K of 6.0K | 0.10 | 0.14-0.15 | 0 |
| aegon-small | B | template | entries | 6.0K of 6.0K | 0.11 | 0.15-0.16 | 0 |
| aegon-small | B | template | patch | 2.4K of 2.4K | 0.10 | 0.15 | 0 |
| aegon-small | B | template | projects | 3.6K of 3.6K | 0.10 | 0.14-0.15 | 0 |
| aegon-small | B | template | session | 6.0K of 6.0K | 0.10 | 0.14-0.15 | 0 |
| aegon-small | B | template | timer | 6.0K of 6.0K | 0.10 | 0.14-0.15 | 0 |
| goose-epoll-rest | B | template | entries | 6.0K of 6.0K | 0.10 | 0.14-0.16 | 0 |
| goose-epoll-rest | B | template | patch | 2.4K of 2.4K | 0.10 | 0.14-0.15 | 0 |
| goose-epoll-rest | B | template | projects | 3.6K of 3.6K | 0.10 | 0.14-0.15 | 0 |
| goose-epoll-rest | B | template | session | 6.0K of 6.0K | 0.10 | 0.13-0.14 | 0 |
| goose-epoll-rest | B | template | timer | 6.0K of 6.0K | 0.10 | 0.14-0.15 | 0 |
| goose-uring-rest | B | template | entries | 6.0K of 6.0K | 0.10 | 0.14 | 0 |
| goose-uring-rest | B | template | patch | 2.4K of 2.4K | 0.10 | 0.14 | 0 |
| goose-uring-rest | B | template | projects | 3.6K of 3.6K | 0.10 | 0.14 | 0 |
| goose-uring-rest | B | template | session | 6.0K of 6.0K | 0.10 | 0.14 | 0 |
| goose-uring-rest | B | template | timer | 6.0K of 6.0K | 0.10 | 0.14 | 0 |
| goose-uring | C | serialize | bookings | 153 of 153 | 0.67-0.69 | 0.85-0.89 | 0 |
| goose-uring | C | serialize | client | 51 of 51 | 0.10-0.11 | 0.15-0.16 | 0 |
| goose-uring | C | serialize | encounter | 204 of 204 | 0.12 | 0.17-0.59 | 0 |
| goose-uring | C | serialize | history | 204 of 204 | 0.14 | 0.28-0.58 | 0 |
| goose-uring | C | serialize | poll | 934 of 935 | 0.10 | 0.41-0.48 | 0 |
| goose-uring | C | serialize | shifts | 153 of 153 | 0.11-0.12 | 0.16 | 0 |
| goose-epoll | C | serialize | bookings | 153 of 153 | 0.68-0.69 | 0.85 | 0 |
| goose-epoll | C | serialize | client | 51 of 51 | 0.10-0.11 | 0.14-0.16 | 0 |
| goose-epoll | C | serialize | encounter | 204 of 204 | 0.12 | 0.18-0.51 | 0 |
| goose-epoll | C | serialize | history | 204 of 204 | 0.14 | 0.24-0.34 | 0 |
| goose-epoll | C | serialize | poll | 933-934 of 935 | 0.10 | 0.43-0.49 | 0 |
| goose-epoll | C | serialize | shifts | 153 of 153 | 0.11-0.12 | 0.15-0.17 | 0 |
| aegon | C | serialize | bookings | 153 of 153 | 0.81-0.82 | 1.16-1.21 | 0 |
| aegon | C | serialize | client | 51 of 51 | 0.11-0.12 | 0.16 | 0 |
| aegon | C | serialize | encounter | 204 of 204 | 0.12-0.13 | 0.18-0.67 | 0 |
| aegon | C | serialize | history | 204 of 204 | 0.15-0.16 | 0.23-0.81 | 0 |
| aegon | C | serialize | poll | 933-935 of 935 | 0.11 | 0.57-0.64 | 0 |
| aegon | C | serialize | shifts | 153 of 153 | 0.12 | 0.17 | 0 |
| aegon-small | C | serialize | bookings | 153 of 153 | 0.81-0.83 | 1.16-1.21 | 0 |
| aegon-small | C | serialize | client | 51 of 51 | 0.11-0.12 | 0.15-0.16 | 0 |
| aegon-small | C | serialize | encounter | 204 of 204 | 0.13 | 0.18-0.72 | 0 |
| aegon-small | C | serialize | history | 204 of 204 | 0.15-0.16 | 0.22-0.49 | 0 |
| aegon-small | C | serialize | poll | 933-934 of 935 | 0.11 | 0.60-0.62 | 0 |
| aegon-small | C | serialize | shifts | 153 of 153 | 0.12 | 0.16-0.18 | 0 |
| goose-epoll-rest | C | serialize | bookings | 153 of 153 | 0.69-0.70 | 0.84-0.88 | 0 |
| goose-epoll-rest | C | serialize | client | 51 of 51 | 0.10-0.11 | 0.14-0.16 | 0 |
| goose-epoll-rest | C | serialize | encounter | 204 of 204 | 0.12 | 0.33-0.64 | 0 |
| goose-epoll-rest | C | serialize | history | 204 of 204 | 0.14-0.15 | 0.21-0.70 | 0 |
| goose-epoll-rest | C | serialize | poll | 933-934 of 935 | 0.10 | 0.48-0.51 | 0 |
| goose-epoll-rest | C | serialize | shifts | 153 of 153 | 0.12 | 0.16-0.17 | 0 |
| goose-uring-rest | C | serialize | bookings | 153 of 153 | 0.68-0.69 | 0.83-0.84 | 0 |
| goose-uring-rest | C | serialize | client | 51 of 51 | 0.11-0.12 | 0.15 | 0 |
| goose-uring-rest | C | serialize | encounter | 204 of 204 | 0.12 | 0.25-0.62 | 0 |
| goose-uring-rest | C | serialize | history | 204 of 204 | 0.14-0.15 | 0.38-0.65 | 0 |
| goose-uring-rest | C | serialize | poll | 933-934 of 935 | 0.10 | 0.43-0.50 | 0 |
| goose-uring-rest | C | serialize | shifts | 153 of 153 | 0.12 | 0.16 | 0 |
| goose-uring | C | template | bookings | 153 of 153 | 0.28 | 0.42-0.45 | 0 |
| goose-uring | C | template | client | 51 of 51 | 0.10-0.11 | 0.14-0.15 | 0 |
| goose-uring | C | template | encounter | 204 of 204 | 0.12 | 0.16 | 0 |
| goose-uring | C | template | history | 204 of 204 | 0.12 | 0.17-0.18 | 0 |
| goose-uring | C | template | poll | 933-935 of 935 | 0.10 | 0.16-0.17 | 0 |
| goose-uring | C | template | shifts | 153 of 153 | 0.10 | 0.14-0.15 | 0 |
| goose-epoll | C | template | bookings | 153 of 153 | 0.28 | 0.43-0.46 | 0 |
| goose-epoll | C | template | client | 51 of 51 | 0.10-0.11 | 0.14-0.16 | 0 |
| goose-epoll | C | template | encounter | 204 of 204 | 0.11-0.12 | 0.15-0.16 | 0 |
| goose-epoll | C | template | history | 204 of 204 | 0.12-0.13 | 0.17-0.18 | 0 |
| goose-epoll | C | template | poll | 934 of 935 | 0.10 | 0.16-0.17 | 0 |
| goose-epoll | C | template | shifts | 153 of 153 | 0.10 | 0.15-0.16 | 0 |
| aegon | C | template | bookings | 153 of 153 | 0.32-0.33 | 0.60-0.72 | 0 |
| aegon | C | template | client | 51 of 51 | 0.11-0.12 | 0.16-0.17 | 0 |
| aegon | C | template | encounter | 204 of 204 | 0.12 | 0.17-0.18 | 0 |
| aegon | C | template | history | 204 of 204 | 0.13-0.14 | 0.18-0.21 | 0 |
| aegon | C | template | poll | 933-934 of 935 | 0.11 | 0.18-0.20 | 0 |
| aegon | C | template | shifts | 153 of 153 | 0.11 | 0.15-0.16 | 0 |
| aegon-small | C | template | bookings | 153 of 153 | 0.33 | 0.61-0.66 | 0 |
| aegon-small | C | template | client | 51 of 51 | 0.11 | 0.15-0.16 | 0 |
| aegon-small | C | template | encounter | 204 of 204 | 0.11-0.12 | 0.16-0.17 | 0 |
| aegon-small | C | template | history | 204 of 204 | 0.13-0.14 | 0.19-0.28 | 0 |
| aegon-small | C | template | poll | 933-935 of 935 | 0.10-0.11 | 0.18-0.20 | 0 |
| aegon-small | C | template | shifts | 153 of 153 | 0.11 | 0.15-0.16 | 0 |
| goose-epoll-rest | C | template | bookings | 153 of 153 | 0.28-0.29 | 0.43-0.44 | 0 |
| goose-epoll-rest | C | template | client | 51 of 51 | 0.11 | 0.15-0.16 | 0 |
| goose-epoll-rest | C | template | encounter | 204 of 204 | 0.12 | 0.16-0.24 | 0 |
| goose-epoll-rest | C | template | history | 204 of 204 | 0.13 | 0.18-0.23 | 0 |
| goose-epoll-rest | C | template | poll | 933-935 of 935 | 0.10 | 0.16-0.17 | 0 |
| goose-epoll-rest | C | template | shifts | 153 of 153 | 0.10-0.11 | 0.14-0.16 | 0 |
| goose-uring-rest | C | template | bookings | 153 of 153 | 0.28-0.29 | 0.45-0.47 | 0 |
| goose-uring-rest | C | template | client | 51 of 51 | 0.11 | 0.15 | 0 |
| goose-uring-rest | C | template | encounter | 204 of 204 | 0.12 | 0.16-0.24 | 0 |
| goose-uring-rest | C | template | history | 204 of 204 | 0.13 | 0.18-0.27 | 0 |
| goose-uring-rest | C | template | poll | 933-934 of 935 | 0.10 | 0.16-0.18 | 0 |
| goose-uring-rest | C | template | shifts | 153 of 153 | 0.10-0.12 | 0.14-0.17 | 0 |

| Server | Tier | Run | CPU µs/req | uploads/s |
|---|---|---|---:|---:|
| goose-uring | A | serialize | 20.8-21.0 |  |
| goose-epoll | A | serialize | 20.8-21.1 |  |
| aegon | A | serialize | 23.0-23.8 |  |
| aegon-small | A | serialize | 22.7-23.9 |  |
| goose-epoll-rest | A | serialize | 20.4-21.2 |  |
| goose-uring-rest | A | serialize | 21.1-21.8 |  |
| goose-uring | A | template | 20.8-21.1 |  |
| goose-epoll | A | template | 20.5-20.9 |  |
| aegon | A | template | 22.3-23.4 |  |
| aegon-small | A | template | 22.6-23.8 |  |
| goose-epoll-rest | A | template | 21.3-21.7 |  |
| goose-uring-rest | A | template | 21.0-21.3 |  |
| goose-uring | B | serialize | 32.0-32.9 |  |
| goose-epoll | B | serialize | 31.7-32.0 |  |
| aegon | B | serialize | 36.6-37.2 |  |
| aegon-small | B | serialize | 36.9-37.2 |  |
| goose-epoll-rest | B | serialize | 31.6-31.8 |  |
| goose-uring-rest | B | serialize | 32.6-33.4 |  |
| goose-uring | B | template | 30.7-32.2 |  |
| goose-epoll | B | template | 30.3-30.4 |  |
| aegon | B | template | 34.8-35.0 |  |
| aegon-small | B | template | 34.4-34.6 |  |
| goose-epoll-rest | B | template | 30.7-31.1 |  |
| goose-uring-rest | B | template | 30.6-31.3 |  |
| goose-uring | C | serialize | 89.5-90.6 |  |
| goose-epoll | C | serialize | 89.1-89.8 |  |
| aegon | C | serialize | 108.7-109.5 |  |
| aegon-small | C | serialize | 109.5-109.9 |  |
| goose-epoll-rest | C | serialize | 92.2-92.6 |  |
| goose-uring-rest | C | serialize | 92.2-92.7 |  |
| goose-uring | C | template | 51.4-53.0 |  |
| goose-epoll | C | template | 50.2-51.8 |  |
| aegon | C | template | 62.0-62.4 |  |
| aegon-small | C | template | 62.8-63.2 |  |
| goose-epoll-rest | C | template | 52.6-53.7 |  |
| goose-uring-rest | C | template | 54.2-55.0 |  |

## Mixed run: tier C's reads, alone and beside uploads

| Server | Tier | Run | Route | rate reached | p50 ms | p99 ms | errors |
|---|---|---|---|---:|---:|---:|---:|
| goose-uring | C | alone | bookings | 153 of 153 | 0.68-0.69 | 0.86 | 0 |
| goose-uring | C | alone | client | 51 of 51 | 0.11 | 0.16 | 0 |
| goose-uring | C | alone | encounter | 204 of 204 | 0.12 | 0.16-0.20 | 0 |
| goose-uring | C | alone | history | 204 of 204 | 0.14 | 0.19-0.24 | 0 |
| goose-uring | C | alone | poll | 933-934 of 935 | 0.10 | 0.49-0.51 | 0 |
| goose-uring | C | alone | shifts | 153 of 153 | 0.11 | 0.15 | 0 |
| goose-epoll | C | alone | bookings | 153 of 153 | 0.67-0.69 | 0.86-0.89 | 0 |
| goose-epoll | C | alone | client | 51 of 51 | 0.10-0.11 | 0.15-0.17 | 0 |
| goose-epoll | C | alone | encounter | 204 of 204 | 0.12 | 0.17-0.30 | 0 |
| goose-epoll | C | alone | history | 204 of 204 | 0.14 | 0.19-0.49 | 0 |
| goose-epoll | C | alone | poll | 933-934 of 935 | 0.10 | 0.43-0.48 | 0 |
| goose-epoll | C | alone | shifts | 153 of 153 | 0.11 | 0.15-0.17 | 0 |
| goose-epoll-rest | C | alone | bookings | 153 of 153 | 0.67-0.68 | 0.83-0.86 | 0 |
| goose-epoll-rest | C | alone | client | 51 of 51 | 0.11-0.12 | 0.15-0.16 | 0 |
| goose-epoll-rest | C | alone | encounter | 204 of 204 | 0.12 | 0.17-0.60 | 0 |
| goose-epoll-rest | C | alone | history | 204 of 204 | 0.14 | 0.20-0.51 | 0 |
| goose-epoll-rest | C | alone | poll | 933-934 of 935 | 0.10 | 0.40-0.48 | 0 |
| goose-epoll-rest | C | alone | shifts | 153 of 153 | 0.11-0.12 | 0.16-0.17 | 0 |
| goose-uring-rest | C | alone | bookings | 153 of 153 | 0.67-0.68 | 0.83-0.85 | 0 |
| goose-uring-rest | C | alone | client | 51 of 51 | 0.11 | 0.15-0.16 | 0 |
| goose-uring-rest | C | alone | encounter | 204 of 204 | 0.12 | 0.17-0.44 | 0 |
| goose-uring-rest | C | alone | history | 204 of 204 | 0.14 | 0.21-0.46 | 0 |
| goose-uring-rest | C | alone | poll | 934 of 935 | 0.10 | 0.41-0.47 | 0 |
| goose-uring-rest | C | alone | shifts | 153 of 153 | 0.11-0.12 | 0.16 | 0 |
| goose-uring | C | uploads | bookings | 153 of 153 | 2.13-2.52 | 5.24-6.27 | 0 |
| goose-uring | C | uploads | client | 51 of 51 | 2.08-2.32 | 6.13-6.70 | 0 |
| goose-uring | C | uploads | encounter | 204 of 204 | 2.06-2.30 | 5.61-7.41 | 0 |
| goose-uring | C | uploads | history | 204 of 204 | 1.70-1.76 | 4.58-5.17 | 0 |
| goose-uring | C | uploads | poll | 933-934 of 935 | 2.10-2.16 | 6.06-7.30 | 0 |
| goose-uring | C | uploads | shifts | 153 of 153 | 1.66-2.11 | 5.45-7.43 | 0 |
| goose-epoll | C | uploads | bookings | 153 of 153 | 0.77-0.78 | 1.38-1.51 | 0 |
| goose-epoll | C | uploads | client | 51 of 51 | 0.14-0.18 | 0.49-0.63 | 0 |
| goose-epoll | C | uploads | encounter | 204 of 204 | 0.16-0.19 | 0.61-0.84 | 0 |
| goose-epoll | C | uploads | history | 204 of 204 | 0.20-0.22 | 0.62-0.71 | 0 |
| goose-epoll | C | uploads | poll | 933-934 of 935 | 0.16-0.17 | 0.81-1.19 | 0 |
| goose-epoll | C | uploads | shifts | 153 of 153 | 0.17-0.21 | 0.67-1.02 | 0 |
| goose-epoll-rest | C | uploads | bookings | 153 of 153 | 0.76-0.78 | 1.22-1.35 | 0 |
| goose-epoll-rest | C | uploads | client | 51 of 51 | 0.17-0.21 | 0.44-0.51 | 0 |
| goose-epoll-rest | C | uploads | encounter | 204 of 204 | 0.18-0.21 | 0.51-0.65 | 0 |
| goose-epoll-rest | C | uploads | history | 204 of 204 | 0.22-0.23 | 0.52-0.79 | 0 |
| goose-epoll-rest | C | uploads | poll | 933-934 of 935 | 0.17-0.18 | 0.74-0.81 | 0 |
| goose-epoll-rest | C | uploads | shifts | 153 of 153 | 0.20 | 0.52-0.74 | 0 |
| goose-uring-rest | C | uploads | bookings | 153 of 153 | 2.56-2.85 | 6.05-6.72 | 0 |
| goose-uring-rest | C | uploads | client | 51 of 51 | 2.45-2.54 | 6.60-7.99 | 0 |
| goose-uring-rest | C | uploads | encounter | 204 of 204 | 2.47-2.65 | 7.03-7.81 | 0 |
| goose-uring-rest | C | uploads | history | 204 of 204 | 1.95-2.40 | 5.16-6.49 | 0 |
| goose-uring-rest | C | uploads | poll | 932-934 of 935 | 2.44-2.74 | 7.63-8.07 | 0 |
| goose-uring-rest | C | uploads | shifts | 153 of 153 | 2.73-2.82 | 7.53-8.07 | 0 |

| Server | Tier | Run | CPU µs/req | uploads/s |
|---|---|---|---:|---:|
| goose-uring | C | alone | 90.3 |  |
| goose-epoll | C | alone | 89.1-91.1 |  |
| goose-epoll-rest | C | alone | 90.3-91.4 |  |
| goose-uring-rest | C | alone | 91.0-92.2 |  |
| goose-uring | C | uploads | 2280.7-2300.8 | 1.2K |
| goose-epoll | C | uploads | 2271.4-2307.4 | 1.1K-1.2K |
| goose-epoll-rest | C | uploads | 2344.1-2353.9 | 1.1K |
| goose-uring-rest | C | uploads | 2314.8-2341.5 | 1.1K |

