## Saturation

| Server | Tier | JSON | req/s, median | range | p50 ms | p99 ms | CPU µs/req | peak RSS MB | errors |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|
| hyper | A | serialize | 284.7K | 281.4K-285.5K | 0.87 | 1.93 | 14.1 | 14 | 0 |
| actix-web | A | serialize | 275.9K | 275.3K-281.0K | 0.98 | 1.31 | 14.5 | 19 | 0 |
| axum | A | serialize | 253.3K | 252.9K-253.3K | 1.03 | 1.50 | 15.8 | 26 | 0 |
| dusty | A | serialize | 359.2K | 338.5K-369.1K | 0.71 | 1.10 | 11.1 | 16 | 0 |
| dusty-routes | A | serialize | 373.9K | 360.8K-377.1K | 0.67 | 1.09 | 10.7 | 15 | 0 |
| ntex | A | serialize | 332.0K | 331.3K-335.3K | 0.76 | 1.20 | 12.0 | 42 | 0 |
| hyper | A | template | 304.2K | 302.5K-306.1K | 0.81 | 1.81 | 13.2 | 16 | 0 |
| actix-web | A | template | 293.1K | 292.0K-296.3K | 0.91 | 1.23 | 13.7 | 22 | 0 |
| axum | A | template | 267.8K | 266.8K-270.6K | 0.92 | 1.48 | 15.0 | 34 | 0 |
| dusty | A | template | 403.2K | 386.9K-429.8K | 0.62 | 1.11 | 9.9 | 18 | 0 |
| dusty-routes | A | template | 408.9K | 404.7K-412.1K | 0.61 | 1.06 | 9.8 | 16 | 0 |
| ntex | A | template | 354.6K | 348.0K-357.1K | 0.73 | 1.12 | 11.3 | 60 | 0 |
| hyper | B | serialize | 157.3K | 155.6K-157.7K | 1.60 | 3.49 | 25.5 | 29 | 0 |
| actix-web | B | serialize | 148.9K | 148.5K-149.8K | 1.65 | 2.47 | 27.0 | 56 | 0 |
| axum | B | serialize | 142.0K | 140.2K-143.0K | 1.77 | 2.71 | 28.3 | 58 | 0 |
| dusty | B | serialize | 177.2K | 166.9K-188.1K | 1.40 | 2.74 | 22.7 | 42 | 0 |
| dusty-routes | B | serialize | 166.4K | 164.7K-167.2K | 1.47 | 2.86 | 24.1 | 41 | 0 |
| ntex | B | serialize | 173.4K | 173.3K-174.5K | 1.40 | 2.61 | 23.1 | 86 | 0 |
| hyper | B | template | 203.2K | 202.5K-203.5K | 1.23 | 2.68 | 19.7 | 45 | 0 |
| actix-web | B | template | 192.0K | 191.3K-193.1K | 1.36 | 1.86 | 20.9 | 70 | 0 |
| axum | B | template | 171.0K | 169.8K-173.3K | 1.48 | 2.20 | 23.5 | 84 | 0 |
| dusty | B | template | 296.4K | 291.3K-297.0K | 0.86 | 1.31 | 13.5 | 54 | 0 |
| dusty-routes | B | template | 311.0K | 303.1K-315.8K | 0.79 | 1.33 | 12.9 | 54 | 0 |
| ntex | B | template | 234.6K | 232.9K-234.8K | 1.05 | 1.79 | 17.1 | 98 | 0 |
| hyper | C | serialize | 33.7K | 33.6K-34.3K | 7.43 | 17.6 | 119.2 | 37 | 0 |
| actix-web | C | serialize | 32.5K | 32.3K-32.7K | 7.61 | 16.0 | 123.4 | 332 | 0 |
| axum | C | serialize | 35.2K | 34.7K-35.4K | 7.05 | 14.7 | 114.2 | 482 | 0 |
| dusty | C | serialize | 25.7K | 25.7K-25.8K | 10.2 | 30.3 | 156.1 | 216 | 0 |
| dusty-routes | C | serialize | 24.6K | 24.5K-24.9K | 10.8 | 33.7 | 163.2 | 216 | 0 |
| ntex | C | serialize | 33.5K | 32.9K-33.6K | 7.23 | 17.5 | 119.4 | 206 | 0 |
| hyper | C | template | 125.3K | 125.0K-126.4K | 1.98 | 4.26 | 31.8 | 74 | 0 |
| actix-web | C | template | 97.3K | 96.7K-97.6K | 2.57 | 4.16 | 41.1 | 384 | 0 |
| axum | C | template | 92.4K | 86.5K-93.2K | 2.70 | 4.44 | 43.3 | 584 | 0 |
| dusty | C | template | 136.3K | 133.4K-136.6K | 1.71 | 3.80 | 29.3 | 241 | 0 |
| dusty-routes | C | template | 138.3K | 135.1K-138.3K | 1.79 | 3.41 | 28.9 | 241 | 0 |
| ntex | C | template | 107.1K | 107.0K-109.2K | 2.27 | 4.62 | 36.9 | 328 | 0 |

## Tier D

| Server | Run | uploads/s | uploads p50 ms | forms role req/s | forms p99 ms | peak RSS MB | upload errors |
|---|---|---:|---:|---:|---:|---:|---:|
| hyper | alone | 1.2K | 14.4-14.7 |  |  | 73 | 0 |
| actix-web | alone | 1.2K | 17.0-17.4 |  |  | 57 | 0 |
| axum | alone | 1.2K | 15.2-15.6 |  |  | 162 | 0 |
| dusty | alone | 1.1K-1.2K | 15.1-15.8 |  |  | 31 | 0 |
| dusty-routes | alone | 1.2K | 14.4-14.5 |  |  | 31 | 0 |
| ntex | alone | 1.2K | 14.5-14.7 |  |  | 86 | 0 |
| hyper | beside forms | 40-51 | 127-172 | 5.2K | 116-157 | 195 | 0 |
| actix-web | beside forms | 94-95 | 193-205 | 4.7K-4.8K | 107-109 | 196 | 0 |
| axum | beside forms | 35-36 | 134-363 | 5.1K-5.2K | 112-120 | 261 | 0 |
| dusty | beside forms | 29-42 | 388-519 | 2.9K-3.0K | 340-642 | 815 | 2 |
| dusty-routes | beside forms | 25-35 | 462-540 | 3.0K-3.1K | 329-356 | 781 | 0 |
| ntex | beside forms | 100-102 | 175-191 | 4.6K-4.7K | 106-108 | 268 | 0 |

## Fixed rate

| Server | Tier | Run | Route | rate reached | p50 ms | p99 ms | errors |
|---|---|---|---|---:|---:|---:|---:|
| hyper | A | serialize | item | 77.7K-77.8K of 78.0K | 0.11 | 0.20-1.90 | 0 |
| hyper | A | serialize | me | 16.0K of 16.0K | 0.10 | 0.19-2.21 | 0 |
| hyper | A | serialize | write | 6.0K of 6.0K | 0.12 | 0.20-0.93 | 0 |
| actix-web | A | serialize | item | 77.8K-77.9K of 78.0K | 0.11 | 0.20-0.21 | 0 |
| actix-web | A | serialize | me | 16.0K of 16.0K | 0.10 | 0.20 | 0 |
| actix-web | A | serialize | write | 6.0K of 6.0K | 0.12 | 0.20 | 0 |
| axum | A | serialize | item | 77.8K of 78.0K | 0.11 | 0.21-6.43 | 0 |
| axum | A | serialize | me | 16.0K of 16.0K | 0.10 | 0.21-2.46 | 0 |
| axum | A | serialize | write | 6.0K of 6.0K | 0.12-0.13 | 0.21-8.11 | 0 |
| dusty | A | serialize | item | 77.8K-77.9K of 78.0K | 0.10-0.11 | 0.19-0.21 | 0 |
| dusty | A | serialize | me | 16.0K of 16.0K | 0.10 | 0.18-0.20 | 0 |
| dusty | A | serialize | write | 6.0K of 6.0K | 0.12 | 0.19-0.21 | 0 |
| dusty-routes | A | serialize | item | 77.8K of 78.0K | 0.10 | 0.18-0.19 | 0 |
| dusty-routes | A | serialize | me | 16.0K of 16.0K | 0.10 | 0.18 | 0 |
| dusty-routes | A | serialize | write | 6.0K of 6.0K | 0.12 | 0.19 | 0 |
| ntex | A | serialize | item | 77.8K-77.9K of 78.0K | 0.12 | 0.21-1.11 | 0 |
| ntex | A | serialize | me | 16.0K of 16.0K | 0.11 | 0.21-0.69 | 0 |
| ntex | A | serialize | write | 6.0K of 6.0K | 0.13 | 0.24-0.39 | 0 |
| hyper | A | template | item | 77.8K of 78.0K | 0.10-0.11 | 0.20 | 0 |
| hyper | A | template | me | 16.0K of 16.0K | 0.10 | 0.19 | 0 |
| hyper | A | template | write | 6.0K of 6.0K | 0.12 | 0.20 | 0 |
| actix-web | A | template | item | 77.7K-77.8K of 78.0K | 0.11 | 0.19-0.20 | 0 |
| actix-web | A | template | me | 16.0K of 16.0K | 0.10 | 0.18-0.19 | 0 |
| actix-web | A | template | write | 6.0K of 6.0K | 0.12 | 0.20 | 0 |
| axum | A | template | item | 77.8K of 78.0K | 0.11 | 0.23 | 0 |
| axum | A | template | me | 16.0K of 16.0K | 0.10 | 0.22 | 0 |
| axum | A | template | write | 6.0K of 6.0K | 0.13 | 0.21-0.23 | 0 |
| dusty | A | template | item | 77.8K of 78.0K | 0.10 | 0.18-0.20 | 0 |
| dusty | A | template | me | 16.0K of 16.0K | 0.10 | 0.17-0.19 | 0 |
| dusty | A | template | write | 6.0K of 6.0K | 0.12 | 0.18-0.20 | 0 |
| dusty-routes | A | template | item | 77.8K of 78.0K | 0.10 | 0.18 | 0 |
| dusty-routes | A | template | me | 16.0K of 16.0K | 0.09-0.10 | 0.17 | 0 |
| dusty-routes | A | template | write | 6.0K of 6.0K | 0.12 | 0.18 | 0 |
| ntex | A | template | item | 77.8K-77.9K of 78.0K | 0.12 | 0.20-0.21 | 0 |
| ntex | A | template | me | 16.0K of 16.0K | 0.11 | 0.19-0.20 | 0 |
| ntex | A | template | write | 6.0K of 6.0K | 0.13 | 0.22-0.24 | 0 |
| hyper | B | serialize | entries | 6.0K of 6.0K | 0.12 | 0.19-0.21 | 0 |
| hyper | B | serialize | patch | 2.4K of 2.4K | 0.11-0.12 | 0.18-0.20 | 0 |
| hyper | B | serialize | projects | 3.6K of 3.6K | 0.11 | 0.18-0.21 | 0 |
| hyper | B | serialize | session | 6.0K of 6.0K | 0.11 | 0.18-0.20 | 0 |
| hyper | B | serialize | timer | 6.0K of 6.0K | 0.10 | 0.17-0.20 | 0 |
| actix-web | B | serialize | entries | 6.0K of 6.0K | 0.12 | 0.17-0.20 | 0 |
| actix-web | B | serialize | patch | 2.4K of 2.4K | 0.12 | 0.17-0.18 | 0 |
| actix-web | B | serialize | projects | 3.6K of 3.6K | 0.11-0.12 | 0.17 | 0 |
| actix-web | B | serialize | session | 6.0K of 6.0K | 0.11 | 0.16-0.17 | 0 |
| actix-web | B | serialize | timer | 6.0K of 6.0K | 0.10-0.11 | 0.16-0.18 | 0 |
| axum | B | serialize | entries | 6.0K of 6.0K | 0.12-0.13 | 0.18-0.19 | 0 |
| axum | B | serialize | patch | 2.4K of 2.4K | 0.12 | 0.17-0.18 | 0 |
| axum | B | serialize | projects | 3.6K of 3.6K | 0.12 | 0.17-0.18 | 0 |
| axum | B | serialize | session | 6.0K of 6.0K | 0.11 | 0.17-0.18 | 0 |
| axum | B | serialize | timer | 6.0K of 6.0K | 0.11 | 0.16-0.18 | 0 |
| dusty | B | serialize | entries | 6.0K of 6.0K | 0.12 | 0.17-0.20 | 0 |
| dusty | B | serialize | patch | 2.4K of 2.4K | 0.11 | 0.17-0.19 | 0 |
| dusty | B | serialize | projects | 3.6K of 3.6K | 0.11 | 0.17-0.19 | 0 |
| dusty | B | serialize | session | 6.0K of 6.0K | 0.10-0.11 | 0.16-0.18 | 0 |
| dusty | B | serialize | timer | 6.0K of 6.0K | 0.10 | 0.16-0.17 | 0 |
| dusty-routes | B | serialize | entries | 6.0K of 6.0K | 0.12 | 0.17-0.18 | 0 |
| dusty-routes | B | serialize | patch | 2.4K of 2.4K | 0.11 | 0.17 | 0 |
| dusty-routes | B | serialize | projects | 3.6K of 3.6K | 0.11 | 0.17 | 0 |
| dusty-routes | B | serialize | session | 6.0K of 6.0K | 0.10-0.11 | 0.16 | 0 |
| dusty-routes | B | serialize | timer | 6.0K of 6.0K | 0.10 | 0.15-0.16 | 0 |
| ntex | B | serialize | entries | 6.0K of 6.0K | 0.13 | 0.19-0.20 | 0 |
| ntex | B | serialize | patch | 2.4K of 2.4K | 0.12 | 0.20-0.21 | 0 |
| ntex | B | serialize | projects | 3.6K of 3.6K | 0.12 | 0.18-0.19 | 0 |
| ntex | B | serialize | session | 6.0K of 6.0K | 0.12 | 0.18-0.19 | 0 |
| ntex | B | serialize | timer | 6.0K of 6.0K | 0.11 | 0.18-0.19 | 0 |
| hyper | B | template | entries | 6.0K of 6.0K | 0.11 | 0.18 | 0 |
| hyper | B | template | patch | 2.4K of 2.4K | 0.11 | 0.18 | 0 |
| hyper | B | template | projects | 3.6K of 3.6K | 0.11 | 0.17-0.18 | 0 |
| hyper | B | template | session | 6.0K of 6.0K | 0.10-0.11 | 0.17-0.18 | 0 |
| hyper | B | template | timer | 6.0K of 6.0K | 0.10-0.11 | 0.17 | 0 |
| actix-web | B | template | entries | 6.0K of 6.0K | 0.11 | 0.16-0.17 | 0 |
| actix-web | B | template | patch | 2.4K of 2.4K | 0.12 | 0.16-0.17 | 0 |
| actix-web | B | template | projects | 3.6K of 3.6K | 0.11 | 0.16 | 0 |
| actix-web | B | template | session | 6.0K of 6.0K | 0.10-0.11 | 0.15-0.16 | 0 |
| actix-web | B | template | timer | 6.0K of 6.0K | 0.10 | 0.15-0.16 | 0 |
| axum | B | template | entries | 6.0K of 6.0K | 0.11-0.12 | 0.16-0.17 | 0 |
| axum | B | template | patch | 2.4K of 2.4K | 0.12 | 0.16-0.18 | 0 |
| axum | B | template | projects | 3.6K of 3.6K | 0.11 | 0.16-0.17 | 0 |
| axum | B | template | session | 6.0K of 6.0K | 0.11 | 0.16-0.17 | 0 |
| axum | B | template | timer | 6.0K of 6.0K | 0.11 | 0.15-0.17 | 0 |
| dusty | B | template | entries | 6.0K of 6.0K | 0.10-0.11 | 0.15-0.16 | 0 |
| dusty | B | template | patch | 2.4K of 2.4K | 0.11 | 0.15-0.16 | 0 |
| dusty | B | template | projects | 3.6K of 3.6K | 0.10-0.11 | 0.15-0.16 | 0 |
| dusty | B | template | session | 6.0K of 6.0K | 0.10 | 0.14-0.15 | 0 |
| dusty | B | template | timer | 6.0K of 6.0K | 0.10 | 0.14-0.15 | 0 |
| dusty-routes | B | template | entries | 6.0K of 6.0K | 0.10 | 0.15 | 0 |
| dusty-routes | B | template | patch | 2.4K of 2.4K | 0.11 | 0.15-0.16 | 0 |
| dusty-routes | B | template | projects | 3.6K of 3.6K | 0.10 | 0.15 | 0 |
| dusty-routes | B | template | session | 6.0K of 6.0K | 0.10 | 0.14-0.15 | 0 |
| dusty-routes | B | template | timer | 6.0K of 6.0K | 0.10 | 0.14-0.15 | 0 |
| ntex | B | template | entries | 6.0K of 6.0K | 0.12 | 0.18 | 0 |
| ntex | B | template | patch | 2.4K of 2.4K | 0.12 | 0.18-0.19 | 0 |
| ntex | B | template | projects | 3.6K of 3.6K | 0.12 | 0.17-0.18 | 0 |
| ntex | B | template | session | 6.0K of 6.0K | 0.11 | 0.17-0.18 | 0 |
| ntex | B | template | timer | 6.0K of 6.0K | 0.11 | 0.17 | 0 |
| hyper | C | serialize | bookings | 153 of 153 | 1.19-1.22 | 1.43-1.44 | 0 |
| hyper | C | serialize | client | 51 of 51 | 0.11-0.12 | 0.15-0.36 | 0 |
| hyper | C | serialize | encounter | 204 of 204 | 0.13-0.14 | 0.26-0.74 | 0 |
| hyper | C | serialize | history | 204 of 204 | 0.19-0.20 | 0.51-1.39 | 0 |
| hyper | C | serialize | poll | 933-934 of 935 | 0.11 | 1.18-1.22 | 0 |
| hyper | C | serialize | shifts | 153 of 153 | 0.13-0.14 | 0.18-0.21 | 0 |
| actix-web | C | serialize | bookings | 153 of 153 | 1.14-1.21 | 1.39-1.44 | 0 |
| actix-web | C | serialize | client | 51 of 51 | 0.13 | 0.17-1.31 | 0 |
| actix-web | C | serialize | encounter | 204 of 204 | 0.15 | 0.32-1.22 | 0 |
| actix-web | C | serialize | history | 204 of 204 | 0.20-0.21 | 0.74-0.99 | 0 |
| actix-web | C | serialize | poll | 933-934 of 935 | 0.11 | 0.97-1.03 | 0 |
| actix-web | C | serialize | shifts | 153 of 153 | 0.13-0.15 | 0.20-0.21 | 0 |
| axum | C | serialize | bookings | 153 of 153 | 1.04-1.10 | 1.38-1.42 | 0 |
| axum | C | serialize | client | 51 of 51 | 0.12-0.13 | 0.15-0.55 | 0 |
| axum | C | serialize | encounter | 204 of 204 | 0.14 | 0.19-0.88 | 0 |
| axum | C | serialize | history | 204 of 204 | 0.19 | 0.34-1.00 | 0 |
| axum | C | serialize | poll | 933-934 of 935 | 0.11-0.12 | 0.78-0.89 | 0 |
| axum | C | serialize | shifts | 153 of 153 | 0.14 | 0.20-0.22 | 0 |
| dusty | C | serialize | bookings | 153 of 153 | 1.48-1.50 | 1.75-2.06 | 0 |
| dusty | C | serialize | client | 51 of 51 | 0.12-0.13 | 0.17-0.20 | 0 |
| dusty | C | serialize | encounter | 204 of 204 | 0.17 | 0.37-1.52 | 0 |
| dusty | C | serialize | history | 204 of 204 | 0.26 | 1.17-1.23 | 0 |
| dusty | C | serialize | poll | 933-934 of 935 | 0.11 | 1.28-1.34 | 0 |
| dusty | C | serialize | shifts | 153 of 153 | 0.14 | 0.20-0.23 | 0 |
| dusty-routes | C | serialize | bookings | 153 of 153 | 1.55-1.57 | 1.79-1.82 | 0 |
| dusty-routes | C | serialize | client | 51 of 51 | 0.11-0.12 | 0.17-1.71 | 0 |
| dusty-routes | C | serialize | encounter | 204 of 204 | 0.17 | 0.41-1.58 | 0 |
| dusty-routes | C | serialize | history | 204 of 204 | 0.24-0.26 | 0.89-1.36 | 0 |
| dusty-routes | C | serialize | poll | 933-934 of 935 | 0.11 | 1.34-1.41 | 0 |
| dusty-routes | C | serialize | shifts | 153 of 153 | 0.14 | 0.20-0.23 | 0 |
| ntex | C | serialize | bookings | 153 of 153 | 1.20-1.23 | 1.46-1.50 | 0 |
| ntex | C | serialize | client | 51 of 51 | 0.12-0.14 | 0.16-0.96 | 0 |
| ntex | C | serialize | encounter | 204 of 204 | 0.15 | 0.22-1.20 | 0 |
| ntex | C | serialize | history | 204 of 204 | 0.20-0.21 | 0.31-1.21 | 0 |
| ntex | C | serialize | poll | 933-934 of 935 | 0.12 | 0.98-1.04 | 0 |
| ntex | C | serialize | shifts | 153 of 153 | 0.14 | 0.18-0.21 | 0 |
| hyper | C | template | bookings | 153 of 153 | 0.27-0.28 | 0.42-0.46 | 0 |
| hyper | C | template | client | 51 of 51 | 0.11 | 0.16-0.17 | 0 |
| hyper | C | template | encounter | 204 of 204 | 0.12 | 0.18-0.27 | 0 |
| hyper | C | template | history | 204 of 204 | 0.14 | 0.19-0.22 | 0 |
| hyper | C | template | poll | 933-934 of 935 | 0.11 | 0.20-0.23 | 0 |
| hyper | C | template | shifts | 153 of 153 | 0.12 | 0.18-0.19 | 0 |
| actix-web | C | template | bookings | 153 of 153 | 0.34-0.36 | 0.51-0.62 | 0 |
| actix-web | C | template | client | 51 of 51 | 0.12 | 0.16-0.17 | 0 |
| actix-web | C | template | encounter | 204 of 204 | 0.13 | 0.17-0.27 | 0 |
| actix-web | C | template | history | 204 of 204 | 0.14-0.15 | 0.20-0.28 | 0 |
| actix-web | C | template | poll | 934 of 935 | 0.11 | 0.19-0.21 | 0 |
| actix-web | C | template | shifts | 153 of 153 | 0.12-0.13 | 0.16-0.18 | 0 |
| axum | C | template | bookings | 153 of 153 | 0.32-0.33 | 0.63-0.70 | 0 |
| axum | C | template | client | 51 of 51 | 0.12-0.13 | 0.17-0.33 | 0 |
| axum | C | template | encounter | 204 of 204 | 0.13 | 0.18 | 0 |
| axum | C | template | history | 204 of 204 | 0.14-0.15 | 0.21-0.25 | 0 |
| axum | C | template | poll | 933-934 of 935 | 0.11-0.12 | 0.20-0.24 | 0 |
| axum | C | template | shifts | 153 of 153 | 0.12-0.13 | 0.17-0.19 | 0 |
| dusty | C | template | bookings | 153 of 153 | 0.26 | 0.40-0.45 | 0 |
| dusty | C | template | client | 51 of 51 | 0.11-0.12 | 0.16-0.24 | 0 |
| dusty | C | template | encounter | 204 of 204 | 0.12 | 0.17-0.19 | 0 |
| dusty | C | template | history | 204 of 204 | 0.14 | 0.19-0.26 | 0 |
| dusty | C | template | poll | 933-934 of 935 | 0.11 | 0.17-0.19 | 0 |
| dusty | C | template | shifts | 153 of 153 | 0.12 | 0.17-0.18 | 0 |
| dusty-routes | C | template | bookings | 153 of 153 | 0.26-0.27 | 0.42-0.45 | 0 |
| dusty-routes | C | template | client | 51 of 51 | 0.11 | 0.14-0.15 | 0 |
| dusty-routes | C | template | encounter | 204 of 204 | 0.12 | 0.17-0.18 | 0 |
| dusty-routes | C | template | history | 204 of 204 | 0.14 | 0.19-0.26 | 0 |
| dusty-routes | C | template | poll | 933-934 of 935 | 0.11 | 0.17-0.19 | 0 |
| dusty-routes | C | template | shifts | 153 of 153 | 0.12 | 0.16-0.17 | 0 |
| ntex | C | template | bookings | 153 of 153 | 0.34-0.35 | 0.67-0.79 | 0 |
| ntex | C | template | client | 51 of 51 | 0.12 | 0.17-0.20 | 0 |
| ntex | C | template | encounter | 204 of 204 | 0.13-0.14 | 0.19-0.25 | 0 |
| ntex | C | template | history | 204 of 204 | 0.15 | 0.26-0.32 | 0 |
| ntex | C | template | poll | 933-934 of 935 | 0.12 | 0.20-0.25 | 0 |
| ntex | C | template | shifts | 153 of 153 | 0.13 | 0.18-0.21 | 0 |

| Server | Tier | Run | CPU µs/req | uploads/s |
|---|---|---|---:|---:|
| hyper | A | serialize | 26.8-27.1 |  |
| actix-web | A | serialize | 26.2-26.4 |  |
| axum | A | serialize | 26.3-27.1 |  |
| dusty | A | serialize | 28.1-28.7 |  |
| dusty-routes | A | serialize | 27.6-28.3 |  |
| ntex | A | serialize | 27.4-27.7 |  |
| hyper | A | template | 25.7-26.0 |  |
| actix-web | A | template | 25.7-26.5 |  |
| axum | A | template | 25.9-26.5 |  |
| dusty | A | template | 26.9-28.4 |  |
| dusty-routes | A | template | 27.2-27.5 |  |
| ntex | A | template | 27.0-28.1 |  |
| hyper | B | serialize | 46.9-47.1 |  |
| actix-web | B | serialize | 43.1-44.1 |  |
| axum | B | serialize | 44.0-45.6 |  |
| dusty | B | serialize | 47.0-47.5 |  |
| dusty-routes | B | serialize | 47.1-47.4 |  |
| ntex | B | serialize | 47.6-48.3 |  |
| hyper | B | template | 42.1-42.5 |  |
| actix-web | B | template | 40.2-40.3 |  |
| axum | B | template | 41.3-41.9 |  |
| dusty | B | template | 40.0-41.2 |  |
| dusty-routes | B | template | 39.7-40.2 |  |
| ntex | B | template | 43.8-45.2 |  |
| hyper | C | serialize | 151.9-152.7 |  |
| actix-web | C | serialize | 152.3-155.8 |  |
| axum | C | serialize | 141.7-144.4 |  |
| dusty | C | serialize | 195.1-197.0 |  |
| dusty-routes | C | serialize | 200.1-202.2 |  |
| ntex | C | serialize | 159.7-161.0 |  |
| hyper | C | template | 58.1-58.9 |  |
| actix-web | C | template | 67.9-69.1 |  |
| axum | C | template | 67.5-68.7 |  |
| dusty | C | template | 61.6-62.8 |  |
| dusty-routes | C | template | 61.6-62.4 |  |
| ntex | C | template | 72.2-73.4 |  |

## Mixed run: tier C's reads, alone and beside uploads

| Server | Tier | Run | Route | rate reached | p50 ms | p99 ms | errors |
|---|---|---|---|---:|---:|---:|---:|
| hyper | C | alone | bookings | 153 of 153 | 1.16-1.22 | 1.42-1.45 | 0 |
| hyper | C | alone | client | 51 of 51 | 0.10-0.12 | 0.16-0.20 | 0 |
| hyper | C | alone | encounter | 204 of 204 | 0.14-0.15 | 0.52-1.14 | 0 |
| hyper | C | alone | history | 204 of 204 | 0.18-0.20 | 0.27-1.36 | 0 |
| hyper | C | alone | poll | 934 of 935 | 0.11 | 1.17-1.20 | 0 |
| hyper | C | alone | shifts | 153 of 153 | 0.13-0.14 | 0.19-0.21 | 0 |
| actix-web | C | alone | bookings | 153 of 153 | 1.17-1.21 | 1.41-1.44 | 0 |
| actix-web | C | alone | client | 51 of 51 | 0.12 | 0.17-0.20 | 0 |
| actix-web | C | alone | encounter | 204 of 204 | 0.14-0.15 | 0.21-1.13 | 0 |
| actix-web | C | alone | history | 204 of 204 | 0.20-0.21 | 0.70-1.19 | 0 |
| actix-web | C | alone | poll | 933-935 of 935 | 0.11 | 0.96-0.99 | 0 |
| actix-web | C | alone | shifts | 153 of 153 | 0.13-0.14 | 0.18-0.21 | 0 |
| axum | C | alone | bookings | 153 of 153 | 1.09-1.10 | 1.34-1.44 | 0 |
| axum | C | alone | client | 51 of 51 | 0.12-0.13 | 0.17-1.17 | 0 |
| axum | C | alone | encounter | 204 of 204 | 0.14-0.15 | 0.47-0.76 | 0 |
| axum | C | alone | history | 204 of 204 | 0.18-0.19 | 0.25-1.02 | 0 |
| axum | C | alone | poll | 933-934 of 935 | 0.12 | 0.88-0.90 | 0 |
| axum | C | alone | shifts | 153 of 153 | 0.14 | 0.19 | 0 |
| dusty | C | alone | bookings | 153 of 153 | 1.48-1.53 | 1.73-1.75 | 0 |
| dusty | C | alone | client | 51 of 51 | 0.11-0.12 | 0.15-1.09 | 0 |
| dusty | C | alone | encounter | 204 of 204 | 0.16-0.17 | 0.35-1.57 | 0 |
| dusty | C | alone | history | 204 of 204 | 0.26 | 0.68-0.81 | 0 |
| dusty | C | alone | poll | 934 of 935 | 0.11 | 1.28-1.30 | 0 |
| dusty | C | alone | shifts | 153 of 153 | 0.14-0.15 | 0.19-0.23 | 0 |
| dusty-routes | C | alone | bookings | 153 of 153 | 1.57-1.60 | 1.81-1.84 | 0 |
| dusty-routes | C | alone | client | 51 of 51 | 0.11-0.14 | 0.21-1.74 | 0 |
| dusty-routes | C | alone | encounter | 204 of 204 | 0.16-0.17 | 1.09-1.57 | 0 |
| dusty-routes | C | alone | history | 204 of 204 | 0.25-0.26 | 0.57-1.72 | 0 |
| dusty-routes | C | alone | poll | 933-934 of 935 | 0.11 | 1.29-1.35 | 0 |
| dusty-routes | C | alone | shifts | 153 of 153 | 0.14-0.15 | 0.20-0.28 | 0 |
| ntex | C | alone | bookings | 153 of 153 | 1.20-1.22 | 1.50-1.58 | 0 |
| ntex | C | alone | client | 51 of 51 | 0.12-0.13 | 0.16-0.37 | 0 |
| ntex | C | alone | encounter | 204 of 204 | 0.14-0.16 | 0.30-1.09 | 0 |
| ntex | C | alone | history | 204 of 204 | 0.21 | 0.60-1.27 | 0 |
| ntex | C | alone | poll | 933 of 935 | 0.12 | 1.00-1.03 | 0 |
| ntex | C | alone | shifts | 153 of 153 | 0.14-0.15 | 0.21-0.22 | 0 |
| hyper | C | uploads | bookings | 153 of 153 | 1.36-1.55 | 4.79-6.64 | 0 |
| hyper | C | uploads | client | 51 of 51 | 0.28-0.64 | 3.86-5.79 | 0 |
| hyper | C | uploads | encounter | 204 of 204 | 0.40-0.67 | 4.01-5.31 | 0 |
| hyper | C | uploads | history | 204 of 204 | 0.39-0.67 | 3.95-5.44 | 0 |
| hyper | C | uploads | poll | 933-934 of 935 | 0.34-0.58 | 3.97-6.68 | 0 |
| hyper | C | uploads | shifts | 153 of 153 | 0.34-0.52 | 3.75-5.44 | 0 |
| actix-web | C | uploads | bookings | 153 of 153 | 6.07-6.39 | 17.7-19.6 | 0 |
| actix-web | C | uploads | client | 51 of 51 | 5.59-6.06 | 16.8-18.5 | 0 |
| actix-web | C | uploads | encounter | 204 of 204 | 5.39-5.79 | 16.7-18.7 | 0 |
| actix-web | C | uploads | history | 204 of 204 | 5.49-5.79 | 17.4-18.9 | 0 |
| actix-web | C | uploads | poll | 932-933 of 935 | 5.51-5.73 | 17.2-18.8 | 0 |
| actix-web | C | uploads | shifts | 153 of 153 | 5.57-5.92 | 17.0-18.9 | 0 |
| axum | C | uploads | bookings | 153 of 153 | 3.90-4.06 | 9.83-10.5 | 0 |
| axum | C | uploads | client | 51 of 51 | 3.11-3.18 | 8.52-9.20 | 0 |
| axum | C | uploads | encounter | 204 of 204 | 3.16-3.30 | 9.39-9.71 | 0 |
| axum | C | uploads | history | 204 of 204 | 3.27-3.31 | 8.88-9.65 | 0 |
| axum | C | uploads | poll | 933-934 of 935 | 3.17-3.29 | 9.22-9.46 | 0 |
| axum | C | uploads | shifts | 153 of 153 | 3.23-3.46 | 9.01-9.47 | 0 |
| dusty | C | uploads | bookings | 153 of 153 | 1.69-1.71 | 3.00-3.08 | 0 |
| dusty | C | uploads | client | 51 of 51 | 0.38-0.41 | 0.74-2.98 | 0 |
| dusty | C | uploads | encounter | 204 of 204 | 0.41-0.42 | 1.20-1.84 | 0 |
| dusty | C | uploads | history | 204 of 204 | 0.50 | 1.35-2.07 | 0 |
| dusty | C | uploads | poll | 933 of 935 | 0.37 | 1.87-1.91 | 0 |
| dusty | C | uploads | shifts | 153 of 153 | 0.40-0.41 | 0.78-0.92 | 0 |
| dusty-routes | C | uploads | bookings | 153 of 153 | 1.69-1.72 | 3.11-3.20 | 0 |
| dusty-routes | C | uploads | client | 51 of 51 | 0.30-0.33 | 0.65-2.67 | 0 |
| dusty-routes | C | uploads | encounter | 204 of 204 | 0.33-0.36 | 1.82-1.98 | 0 |
| dusty-routes | C | uploads | history | 204 of 204 | 0.41-0.45 | 1.57-2.29 | 0 |
| dusty-routes | C | uploads | poll | 933-935 of 935 | 0.28-0.31 | 1.85-2.54 | 0 |
| dusty-routes | C | uploads | shifts | 153 of 153 | 0.30-0.39 | 0.72-2.73 | 0 |
| ntex | C | uploads | bookings | 153 of 153 | 2.13-2.17 | 4.66-4.83 | 0 |
| ntex | C | uploads | client | 51 of 51 | 0.68-0.70 | 1.83-2.12 | 0 |
| ntex | C | uploads | encounter | 204 of 204 | 0.70-0.76 | 2.44-2.46 | 0 |
| ntex | C | uploads | history | 204 of 204 | 0.78-0.80 | 2.49-2.52 | 0 |
| ntex | C | uploads | poll | 933 of 935 | 0.68-0.72 | 2.58-2.62 | 0 |
| ntex | C | uploads | shifts | 153 of 153 | 0.70-0.71 | 2.01-2.14 | 0 |

| Server | Tier | Run | CPU µs/req | uploads/s |
|---|---|---|---:|---:|
| hyper | C | alone | 150.7-153.0 |  |
| actix-web | C | alone | 154.3-156.6 |  |
| axum | C | alone | 143.3-145.2 |  |
| dusty | C | alone | 195.1-196.2 |  |
| dusty-routes | C | alone | 202.9-203.4 |  |
| ntex | C | alone | 159.8-161.4 |  |
| hyper | C | uploads | 2139.4-2183.8 | 1.2K |
| actix-web | C | uploads | 2198.1-2229.9 | 1.2K |
| axum | C | uploads | 2174.9-2196.7 | 1.1K-1.2K |
| dusty | C | uploads | 2355.6-2367.9 | 1.1K |
| dusty-routes | C | uploads | 2349.6-2354.4 | 1.2K |
| ntex | C | uploads | 2250.4-2255.1 | 1.2K |

