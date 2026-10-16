## Saturation

| Server | Tier | JSON | req/s, median | range | p50 ms | p99 ms | CPU µs/req | peak RSS MB | errors |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|
| hyper | A | serialize | 277.8K | 277.2K-284.7K | 0.89 | 1.96 | 14.4 | 13 | 0 |
| actix-web | A | serialize | 262.2K | 261.1K-262.5K | 1.03 | 1.35 | 15.3 | 20 | 0 |
| axum | A | serialize | 241.8K | 240.3K-245.1K | 1.06 | 1.58 | 16.6 | 27 | 0 |
| dusty | A | serialize | 353.1K | 350.3K-366.6K | 0.64 | 1.29 | 11.3 | 16 | 0 |
| dusty-routes | A | serialize | 348.6K | 346.9K-362.0K | 0.73 | 1.22 | 11.5 | 15 | 0 |
| hyper | A | template | 299.8K | 298.3K-299.9K | 0.83 | 1.82 | 13.4 | 16 | 0 |
| actix-web | A | template | 279.4K | 278.5K-281.4K | 0.96 | 1.28 | 14.3 | 22 | 0 |
| axum | A | template | 253.8K | 252.7K-254.2K | 1.00 | 1.65 | 15.8 | 35 | 0 |
| dusty | A | template | 391.0K | 384.9K-396.5K | 0.64 | 1.00 | 10.2 | 18 | 0 |
| dusty-routes | A | template | 393.6K | 392.6K-408.3K | 0.63 | 1.05 | 10.2 | 16 | 0 |
| hyper | B | serialize | 154.1K | 154.0K-154.5K | 1.62 | 3.57 | 26.0 | 29 | 0 |
| actix-web | B | serialize | 142.8K | 142.4K-146.3K | 1.71 | 2.62 | 28.1 | 57 | 0 |
| axum | B | serialize | 139.3K | 136.0K-139.9K | 1.80 | 2.77 | 28.8 | 58 | 0 |
| dusty | B | serialize | 164.3K | 163.6K-166.2K | 1.35 | 3.03 | 24.4 | 42 | 0 |
| dusty-routes | B | serialize | 162.7K | 161.4K-165.7K | 1.45 | 2.91 | 24.7 | 41 | 0 |
| hyper | B | template | 201.5K | 200.6K-202.8K | 1.24 | 2.70 | 19.9 | 45 | 0 |
| actix-web | B | template | 187.4K | 185.3K-188.8K | 1.40 | 1.91 | 21.4 | 68 | 0 |
| axum | B | template | 166.0K | 165.9K-166.0K | 1.53 | 2.34 | 24.2 | 85 | 0 |
| dusty | B | template | 288.4K | 283.7K-289.2K | 0.87 | 1.31 | 13.9 | 55 | 0 |
| dusty-routes | B | template | 298.7K | 296.0K-301.2K | 0.82 | 1.28 | 13.4 | 54 | 0 |
| hyper | C | serialize | 33.2K | 33.0K-33.2K | 7.53 | 17.8 | 121.0 | 37 | 0 |
| actix-web | C | serialize | 31.9K | 31.5K-32.1K | 7.72 | 16.7 | 125.6 | 338 | 0 |
| axum | C | serialize | 34.6K | 34.5K-35.1K | 7.16 | 14.8 | 116.0 | 491 | 0 |
| dusty | C | serialize | 25.4K | 25.3K-25.5K | 10.6 | 33.5 | 158.2 | 216 | 0 |
| dusty-routes | C | serialize | 23.8K | 23.8K-24.1K | 11.0 | 37.5 | 168.3 | 216 | 0 |
| hyper | C | template | 124.1K | 123.7K-124.3K | 2.01 | 4.30 | 32.0 | 74 | 0 |
| actix-web | C | template | 92.6K | 90.1K-93.4K | 2.70 | 4.42 | 43.3 | 395 | 0 |
| axum | C | template | 89.1K | 88.6K-89.4K | 2.78 | 4.91 | 45.0 | 579 | 0 |
| dusty | C | template | 130.1K | 127.8K-132.0K | 1.89 | 4.06 | 30.7 | 242 | 0 |
| dusty-routes | C | template | 132.5K | 128.3K-132.5K | 1.86 | 3.44 | 30.1 | 242 | 0 |

## Tier D

| Server | Run | uploads/s | uploads p50 ms | forms role req/s | forms p99 ms | peak RSS MB | upload errors |
|---|---|---:|---:|---:|---:|---:|---:|
| hyper | alone | 1.1K | 14.8-15.0 |  |  | 76 | 0 |
| actix-web | alone | 1.1K-1.2K | 18.5-18.7 |  |  | 56 | 0 |
| axum | alone | 1.1K-1.2K | 14.8-15.6 |  |  | 148 | 0 |
| dusty | alone | 1.1K | 15.3-15.7 |  |  | 31 | 0 |
| dusty-routes | alone | 1.2K | 14.4-14.5 |  |  | 31 | 0 |
| hyper | beside forms | 42-65 | 135-151 | 4.9K-5.1K | 122-173 | 199 | 0 |
| actix-web | beside forms | 93 | 198-207 | 4.7K | 111-113 | 182 | 0 |
| axum | beside forms | 33-35 | 246-312 | 5.0K | 118-120 | 256 | 0 |
| dusty | beside forms | 27-41 | 382-534 | 3.0K | 331-628 | 815 | 0 |
| dusty-routes | beside forms | 31-37 | 460-537 | 3.0K | 324-341 | 781 | 0 |

## Fixed rate

| Server | Tier | Run | Route | rate reached | p50 ms | p99 ms | errors |
|---|---|---|---|---:|---:|---:|---:|
| hyper | A | serialize | item | 77.8K of 78.0K | 0.11 | 0.20-0.21 | 0 |
| hyper | A | serialize | me | 16.0K of 16.0K | 0.10 | 0.19-0.20 | 0 |
| hyper | A | serialize | write | 6.0K of 6.0K | 0.12 | 0.20-0.21 | 0 |
| actix-web | A | serialize | item | 77.7K-77.8K of 78.0K | 0.11 | 0.21-0.23 | 0 |
| actix-web | A | serialize | me | 16.0K of 16.0K | 0.10-0.11 | 0.20-0.21 | 0 |
| actix-web | A | serialize | write | 6.0K of 6.0K | 0.12 | 0.20-0.21 | 0 |
| axum | A | serialize | item | 77.7K-77.8K of 78.0K | 0.12 | 0.24-2.58 | 0 |
| axum | A | serialize | me | 16.0K of 16.0K | 0.11 | 0.23-1.51 | 0 |
| axum | A | serialize | write | 6.0K of 6.0K | 0.13 | 0.22-0.81 | 0 |
| dusty | A | serialize | item | 77.8K of 78.0K | 0.10-0.11 | 0.18 | 0 |
| dusty | A | serialize | me | 16.0K of 16.0K | 0.10 | 0.17-0.18 | 0 |
| dusty | A | serialize | write | 6.0K of 6.0K | 0.12 | 0.19 | 0 |
| dusty-routes | A | serialize | item | 77.8K of 78.0K | 0.10-0.11 | 0.18-0.78 | 0 |
| dusty-routes | A | serialize | me | 16.0K of 16.0K | 0.10 | 0.17-0.33 | 0 |
| dusty-routes | A | serialize | write | 6.0K of 6.0K | 0.12 | 0.19-0.24 | 0 |
| hyper | A | template | item | 77.8K-77.9K of 78.0K | 0.11 | 0.19-0.20 | 0 |
| hyper | A | template | me | 16.0K of 16.0K | 0.10 | 0.19 | 0 |
| hyper | A | template | write | 6.0K of 6.0K | 0.12 | 0.20 | 0 |
| actix-web | A | template | item | 77.8K of 78.0K | 0.11 | 0.19-0.20 | 0 |
| actix-web | A | template | me | 16.0K of 16.0K | 0.10 | 0.18-0.19 | 0 |
| actix-web | A | template | write | 6.0K of 6.0K | 0.12 | 0.20 | 0 |
| axum | A | template | item | 77.8K-77.9K of 78.0K | 0.11 | 0.21-0.23 | 0 |
| axum | A | template | me | 16.0K of 16.0K | 0.10 | 0.21-0.23 | 0 |
| axum | A | template | write | 6.0K of 6.0K | 0.12-0.13 | 0.21-0.24 | 0 |
| dusty | A | template | item | 77.7K-77.8K of 78.0K | 0.10 | 0.18 | 0 |
| dusty | A | template | me | 16.0K of 16.0K | 0.10 | 0.17 | 0 |
| dusty | A | template | write | 6.0K of 6.0K | 0.12 | 0.18 | 0 |
| dusty-routes | A | template | item | 77.8K of 78.0K | 0.10 | 0.17-0.20 | 0 |
| dusty-routes | A | template | me | 16.0K of 16.0K | 0.10 | 0.17-0.19 | 0 |
| dusty-routes | A | template | write | 6.0K of 6.0K | 0.12 | 0.18-0.20 | 0 |
| hyper | B | serialize | entries | 6.0K of 6.0K | 0.12-0.13 | 0.20 | 0 |
| hyper | B | serialize | patch | 2.4K of 2.4K | 0.11 | 0.18 | 0 |
| hyper | B | serialize | projects | 3.6K of 3.6K | 0.11-0.12 | 0.18-0.19 | 0 |
| hyper | B | serialize | session | 6.0K of 6.0K | 0.11 | 0.18 | 0 |
| hyper | B | serialize | timer | 6.0K of 6.0K | 0.10 | 0.18 | 0 |
| actix-web | B | serialize | entries | 6.0K of 6.0K | 0.13 | 0.18-0.20 | 0 |
| actix-web | B | serialize | patch | 2.4K of 2.4K | 0.12 | 0.18 | 0 |
| actix-web | B | serialize | projects | 3.6K of 3.6K | 0.12 | 0.17-0.18 | 0 |
| actix-web | B | serialize | session | 6.0K of 6.0K | 0.11 | 0.17-0.19 | 0 |
| actix-web | B | serialize | timer | 6.0K of 6.0K | 0.11 | 0.17-0.18 | 0 |
| axum | B | serialize | entries | 6.0K of 6.0K | 0.13 | 0.19-0.21 | 0 |
| axum | B | serialize | patch | 2.4K of 2.4K | 0.12 | 0.18 | 0 |
| axum | B | serialize | projects | 3.6K of 3.6K | 0.12 | 0.18 | 0 |
| axum | B | serialize | session | 6.0K of 6.0K | 0.11 | 0.18-0.22 | 0 |
| axum | B | serialize | timer | 6.0K of 6.0K | 0.11 | 0.16-0.17 | 0 |
| dusty | B | serialize | entries | 6.0K of 6.0K | 0.12 | 0.17-0.18 | 0 |
| dusty | B | serialize | patch | 2.4K of 2.4K | 0.11 | 0.17 | 0 |
| dusty | B | serialize | projects | 3.6K of 3.6K | 0.11 | 0.17 | 0 |
| dusty | B | serialize | session | 6.0K of 6.0K | 0.11 | 0.16 | 0 |
| dusty | B | serialize | timer | 6.0K of 6.0K | 0.10 | 0.15-0.16 | 0 |
| dusty-routes | B | serialize | entries | 6.0K of 6.0K | 0.12 | 0.18 | 0 |
| dusty-routes | B | serialize | patch | 2.4K of 2.4K | 0.11 | 0.17 | 0 |
| dusty-routes | B | serialize | projects | 3.6K of 3.6K | 0.11 | 0.17 | 0 |
| dusty-routes | B | serialize | session | 6.0K of 6.0K | 0.10-0.11 | 0.16 | 0 |
| dusty-routes | B | serialize | timer | 6.0K of 6.0K | 0.10 | 0.15-0.16 | 0 |
| hyper | B | template | entries | 6.0K of 6.0K | 0.11 | 0.18 | 0 |
| hyper | B | template | patch | 2.4K of 2.4K | 0.11 | 0.17-0.18 | 0 |
| hyper | B | template | projects | 3.6K of 3.6K | 0.11 | 0.17-0.18 | 0 |
| hyper | B | template | session | 6.0K of 6.0K | 0.10-0.11 | 0.17-0.18 | 0 |
| hyper | B | template | timer | 6.0K of 6.0K | 0.10-0.11 | 0.17-0.18 | 0 |
| actix-web | B | template | entries | 6.0K of 6.0K | 0.11-0.12 | 0.16-0.17 | 0 |
| actix-web | B | template | patch | 2.4K of 2.4K | 0.12 | 0.16-0.17 | 0 |
| actix-web | B | template | projects | 3.6K of 3.6K | 0.11 | 0.15-0.16 | 0 |
| actix-web | B | template | session | 6.0K of 6.0K | 0.10-0.11 | 0.15 | 0 |
| actix-web | B | template | timer | 6.0K of 6.0K | 0.10-0.11 | 0.15-0.16 | 0 |
| axum | B | template | entries | 6.0K of 6.0K | 0.12 | 0.17-0.18 | 0 |
| axum | B | template | patch | 2.4K of 2.4K | 0.12 | 0.17 | 0 |
| axum | B | template | projects | 3.6K of 3.6K | 0.11 | 0.17 | 0 |
| axum | B | template | session | 6.0K of 6.0K | 0.11 | 0.18 | 0 |
| axum | B | template | timer | 6.0K of 6.0K | 0.11 | 0.17-0.18 | 0 |
| dusty | B | template | entries | 6.0K of 6.0K | 0.11 | 0.15 | 0 |
| dusty | B | template | patch | 2.4K of 2.4K | 0.11 | 0.15 | 0 |
| dusty | B | template | projects | 3.6K of 3.6K | 0.10 | 0.15 | 0 |
| dusty | B | template | session | 6.0K of 6.0K | 0.10 | 0.14-0.15 | 0 |
| dusty | B | template | timer | 6.0K of 6.0K | 0.10 | 0.15 | 0 |
| dusty-routes | B | template | entries | 6.0K of 6.0K | 0.10 | 0.15 | 0 |
| dusty-routes | B | template | patch | 2.4K of 2.4K | 0.11 | 0.15-0.16 | 0 |
| dusty-routes | B | template | projects | 3.6K of 3.6K | 0.10 | 0.15 | 0 |
| dusty-routes | B | template | session | 6.0K of 6.0K | 0.10 | 0.15 | 0 |
| dusty-routes | B | template | timer | 6.0K of 6.0K | 0.10 | 0.14-0.15 | 0 |
| hyper | C | serialize | bookings | 153 of 153 | 1.18-1.25 | 1.45-1.46 | 0 |
| hyper | C | serialize | client | 51 of 51 | 0.11 | 0.17 | 0 |
| hyper | C | serialize | encounter | 204 of 204 | 0.14-0.15 | 0.29-1.10 | 0 |
| hyper | C | serialize | history | 204 of 204 | 0.18-0.19 | 0.45-1.36 | 0 |
| hyper | C | serialize | poll | 934 of 935 | 0.11 | 1.21-1.22 | 0 |
| hyper | C | serialize | shifts | 153 of 153 | 0.14-0.16 | 0.19-0.33 | 0 |
| actix-web | C | serialize | bookings | 153 of 153 | 1.17-1.20 | 1.41-1.44 | 0 |
| actix-web | C | serialize | client | 51 of 51 | 0.11-0.12 | 0.14-0.16 | 0 |
| actix-web | C | serialize | encounter | 204 of 204 | 0.15 | 0.39-1.07 | 0 |
| actix-web | C | serialize | history | 204 of 204 | 0.20-0.21 | 0.32-1.25 | 0 |
| actix-web | C | serialize | poll | 933-935 of 935 | 0.11 | 0.95-1.00 | 0 |
| actix-web | C | serialize | shifts | 153 of 153 | 0.13-0.14 | 0.18-0.24 | 0 |
| axum | C | serialize | bookings | 153 of 153 | 1.06-1.10 | 1.31-1.38 | 0 |
| axum | C | serialize | client | 51 of 51 | 0.13 | 0.17 | 0 |
| axum | C | serialize | encounter | 204 of 204 | 0.14-0.15 | 0.23-1.12 | 0 |
| axum | C | serialize | history | 204 of 204 | 0.18 | 0.73-1.06 | 0 |
| axum | C | serialize | poll | 933-934 of 935 | 0.12 | 0.85-0.91 | 0 |
| axum | C | serialize | shifts | 153 of 153 | 0.14-0.16 | 0.20-0.56 | 0 |
| dusty | C | serialize | bookings | 153 of 153 | 1.49-1.52 | 1.72-1.89 | 0 |
| dusty | C | serialize | client | 51 of 51 | 0.11 | 0.15-0.17 | 0 |
| dusty | C | serialize | encounter | 204 of 204 | 0.17 | 0.44-1.00 | 0 |
| dusty | C | serialize | history | 204 of 204 | 0.24-0.25 | 0.55-1.51 | 0 |
| dusty | C | serialize | poll | 933 of 935 | 0.11 | 1.24-1.38 | 0 |
| dusty | C | serialize | shifts | 153 of 153 | 0.14-0.15 | 0.23-0.56 | 0 |
| dusty-routes | C | serialize | bookings | 153 of 153 | 1.56-1.61 | 1.82-1.85 | 0 |
| dusty-routes | C | serialize | client | 51 of 51 | 0.11-0.12 | 0.14-0.18 | 0 |
| dusty-routes | C | serialize | encounter | 204 of 204 | 0.17 | 0.65-1.64 | 0 |
| dusty-routes | C | serialize | history | 204 of 204 | 0.25-0.26 | 0.58-1.18 | 0 |
| dusty-routes | C | serialize | poll | 934 of 935 | 0.11 | 1.34-1.42 | 0 |
| dusty-routes | C | serialize | shifts | 153 of 153 | 0.14-0.15 | 0.20-0.32 | 0 |
| hyper | C | template | bookings | 153 of 153 | 0.28-0.29 | 0.43-0.47 | 0 |
| hyper | C | template | client | 51 of 51 | 0.11-0.12 | 0.17-0.19 | 0 |
| hyper | C | template | encounter | 204 of 204 | 0.12-0.13 | 0.18-0.19 | 0 |
| hyper | C | template | history | 204 of 204 | 0.13-0.14 | 0.18-0.24 | 0 |
| hyper | C | template | poll | 934 of 935 | 0.11 | 0.20-0.23 | 0 |
| hyper | C | template | shifts | 153 of 153 | 0.11-0.12 | 0.17 | 0 |
| actix-web | C | template | bookings | 153 of 153 | 0.35-0.36 | 0.52-0.53 | 0 |
| actix-web | C | template | client | 51 of 51 | 0.11-0.12 | 0.16-0.17 | 0 |
| actix-web | C | template | encounter | 204 of 204 | 0.12-0.13 | 0.17-0.19 | 0 |
| actix-web | C | template | history | 204 of 204 | 0.14-0.15 | 0.20-0.21 | 0 |
| actix-web | C | template | poll | 933-934 of 935 | 0.11 | 0.19-0.24 | 0 |
| actix-web | C | template | shifts | 153 of 153 | 0.12-0.13 | 0.17-0.19 | 0 |
| axum | C | template | bookings | 153 of 153 | 0.32 | 0.63-0.81 | 0 |
| axum | C | template | client | 51 of 51 | 0.12-0.13 | 0.17 | 0 |
| axum | C | template | encounter | 204 of 204 | 0.13 | 0.18-0.19 | 0 |
| axum | C | template | history | 204 of 204 | 0.14 | 0.20 | 0 |
| axum | C | template | poll | 934 of 935 | 0.12 | 0.18-0.19 | 0 |
| axum | C | template | shifts | 153 of 153 | 0.12 | 0.17 | 0 |
| dusty | C | template | bookings | 153 of 153 | 0.25-0.27 | 0.44-0.46 | 0 |
| dusty | C | template | client | 51 of 51 | 0.11-0.12 | 0.15-0.17 | 0 |
| dusty | C | template | encounter | 204 of 204 | 0.12-0.13 | 0.18-0.25 | 0 |
| dusty | C | template | history | 204 of 204 | 0.13-0.14 | 0.19-0.22 | 0 |
| dusty | C | template | poll | 933 of 935 | 0.11 | 0.18-0.19 | 0 |
| dusty | C | template | shifts | 153 of 153 | 0.11-0.12 | 0.16-0.17 | 0 |
| dusty-routes | C | template | bookings | 153 of 153 | 0.26-0.27 | 0.43-0.45 | 0 |
| dusty-routes | C | template | client | 51 of 51 | 0.11 | 0.15-0.16 | 0 |
| dusty-routes | C | template | encounter | 204 of 204 | 0.12 | 0.17-0.19 | 0 |
| dusty-routes | C | template | history | 204 of 204 | 0.13 | 0.18-0.25 | 0 |
| dusty-routes | C | template | poll | 934-935 of 935 | 0.11 | 0.17-0.18 | 0 |
| dusty-routes | C | template | shifts | 153 of 153 | 0.11-0.12 | 0.16-0.17 | 0 |

| Server | Tier | Run | CPU µs/req | uploads/s |
|---|---|---|---:|---:|
| hyper | A | serialize | 26.7-26.8 |  |
| actix-web | A | serialize | 25.7-26.8 |  |
| axum | A | serialize | 26.1-26.6 |  |
| dusty | A | serialize | 27.4-27.7 |  |
| dusty-routes | A | serialize | 28.1-28.3 |  |
| hyper | A | template | 26.1-26.6 |  |
| actix-web | A | template | 26.0-26.6 |  |
| axum | A | template | 26.4-26.9 |  |
| dusty | A | template | 26.8-27.2 |  |
| dusty-routes | A | template | 27.4-27.8 |  |
| hyper | B | serialize | 47.0-47.6 |  |
| actix-web | B | serialize | 44.3-44.4 |  |
| axum | B | serialize | 44.8-45.7 |  |
| dusty | B | serialize | 46.9-47.5 |  |
| dusty-routes | B | serialize | 46.5-47.3 |  |
| hyper | B | template | 42.0-42.4 |  |
| actix-web | B | template | 40.5-41.0 |  |
| axum | B | template | 41.6-42.0 |  |
| dusty | B | template | 40.5-40.6 |  |
| dusty-routes | B | template | 39.7-40.4 |  |
| hyper | C | serialize | 154.2-155.7 |  |
| actix-web | C | serialize | 153.5-157.0 |  |
| axum | C | serialize | 144.5-145.2 |  |
| dusty | C | serialize | 194.3-197.5 |  |
| dusty-routes | C | serialize | 201.7-204.1 |  |
| hyper | C | template | 59.2-59.6 |  |
| actix-web | C | template | 68.7-69.9 |  |
| axum | C | template | 68.3-68.7 |  |
| dusty | C | template | 62.4-63.2 |  |
| dusty-routes | C | template | 60.0-62.0 |  |

## Mixed run: tier C's reads, alone and beside uploads

| Server | Tier | Run | Route | rate reached | p50 ms | p99 ms | errors |
|---|---|---|---|---:|---:|---:|---:|
| hyper | C | alone | bookings | 153 of 153 | 1.20-1.25 | 1.45-1.47 | 0 |
| hyper | C | alone | client | 51 of 51 | 0.12 | 0.17-0.18 | 0 |
| hyper | C | alone | encounter | 204 of 204 | 0.14-0.15 | 0.27-1.27 | 0 |
| hyper | C | alone | history | 204 of 204 | 0.18-0.19 | 0.64-1.40 | 0 |
| hyper | C | alone | poll | 933-934 of 935 | 0.11 | 1.21-1.25 | 0 |
| hyper | C | alone | shifts | 153 of 153 | 0.14-0.21 | 0.21-0.46 | 0 |
| actix-web | C | alone | bookings | 153 of 153 | 1.19-1.22 | 1.44 | 0 |
| actix-web | C | alone | client | 51 of 51 | 0.13 | 0.17 | 0 |
| actix-web | C | alone | encounter | 204 of 204 | 0.14-0.15 | 0.21-0.55 | 0 |
| actix-web | C | alone | history | 204 of 204 | 0.20-0.21 | 0.27-0.42 | 0 |
| actix-web | C | alone | poll | 933-934 of 935 | 0.11 | 0.99-1.03 | 0 |
| actix-web | C | alone | shifts | 153 of 153 | 0.14 | 0.20-0.23 | 0 |
| axum | C | alone | bookings | 153 of 153 | 1.05-1.06 | 1.30-1.38 | 0 |
| axum | C | alone | client | 51 of 51 | 0.12-0.13 | 0.17-0.18 | 0 |
| axum | C | alone | encounter | 204 of 204 | 0.15 | 0.47-0.84 | 0 |
| axum | C | alone | history | 204 of 204 | 0.18-0.19 | 0.70-0.89 | 0 |
| axum | C | alone | poll | 933-934 of 935 | 0.12 | 0.83-0.90 | 0 |
| axum | C | alone | shifts | 153 of 153 | 0.14-0.15 | 0.19-0.26 | 0 |
| dusty | C | alone | bookings | 153 of 153 | 1.48-1.54 | 1.75-1.81 | 0 |
| dusty | C | alone | client | 51 of 51 | 0.11 | 0.15-0.18 | 0 |
| dusty | C | alone | encounter | 204 of 204 | 0.17 | 0.61-1.56 | 0 |
| dusty | C | alone | history | 204 of 204 | 0.24-0.26 | 0.38-1.50 | 0 |
| dusty | C | alone | poll | 933-935 of 935 | 0.11 | 1.27-1.30 | 0 |
| dusty | C | alone | shifts | 153 of 153 | 0.14-0.15 | 0.19-0.75 | 0 |
| dusty-routes | C | alone | bookings | 153 of 153 | 1.55-1.60 | 1.82-1.91 | 0 |
| dusty-routes | C | alone | client | 51 of 51 | 0.11-0.12 | 0.16-0.17 | 0 |
| dusty-routes | C | alone | encounter | 204 of 204 | 0.17 | 1.17-1.46 | 0 |
| dusty-routes | C | alone | history | 204 of 204 | 0.24-0.26 | 0.82-1.51 | 0 |
| dusty-routes | C | alone | poll | 933-934 of 935 | 0.11 | 1.34-1.40 | 0 |
| dusty-routes | C | alone | shifts | 153 of 153 | 0.14-0.15 | 0.22-0.29 | 0 |
| hyper | C | uploads | bookings | 153 of 153 | 1.39-1.44 | 4.63-4.98 | 0 |
| hyper | C | uploads | client | 51 of 51 | 0.25-0.75 | 3.68-4.27 | 0 |
| hyper | C | uploads | encounter | 204 of 204 | 0.36-0.51 | 4.22-4.38 | 0 |
| hyper | C | uploads | history | 204 of 204 | 0.51-0.54 | 4.13-4.45 | 0 |
| hyper | C | uploads | poll | 933 of 935 | 0.35-0.45 | 4.25-4.57 | 0 |
| hyper | C | uploads | shifts | 153 of 153 | 0.33-0.74 | 4.13-4.44 | 0 |
| actix-web | C | uploads | bookings | 153 of 153 | 7.81-8.37 | 20.0-22.0 | 0 |
| actix-web | C | uploads | client | 51 of 51 | 6.72-7.51 | 18.2-20.4 | 0 |
| actix-web | C | uploads | encounter | 204 of 204 | 7.28-7.59 | 19.3-20.9 | 0 |
| actix-web | C | uploads | history | 204 of 204 | 7.12-7.72 | 18.1-21.2 | 0 |
| actix-web | C | uploads | poll | 933-934 of 935 | 7.22-7.66 | 19.5-21.1 | 0 |
| actix-web | C | uploads | shifts | 153 of 153 | 6.76-8.09 | 18.3-21.6 | 0 |
| axum | C | uploads | bookings | 153 of 153 | 4.10-4.23 | 10.6-11.3 | 0 |
| axum | C | uploads | client | 51 of 51 | 3.38-3.46 | 9.71-10.5 | 0 |
| axum | C | uploads | encounter | 204 of 204 | 3.02-3.83 | 9.94-10.2 | 0 |
| axum | C | uploads | history | 204 of 204 | 3.44-3.80 | 9.70-10.6 | 0 |
| axum | C | uploads | poll | 932-933 of 935 | 3.38-3.54 | 9.98-10.8 | 0 |
| axum | C | uploads | shifts | 153 of 153 | 3.22-3.69 | 9.60-9.92 | 0 |
| dusty | C | uploads | bookings | 153 of 153 | 1.70-1.71 | 3.06-3.21 | 0 |
| dusty | C | uploads | client | 51 of 51 | 0.36-0.40 | 0.74-1.42 | 0 |
| dusty | C | uploads | encounter | 204 of 204 | 0.42-0.43 | 1.88-2.63 | 0 |
| dusty | C | uploads | history | 204 of 204 | 0.50-0.51 | 1.93-2.90 | 0 |
| dusty | C | uploads | poll | 933-934 of 935 | 0.37-0.38 | 2.25-2.38 | 0 |
| dusty | C | uploads | shifts | 153 of 153 | 0.41-0.47 | 1.24-3.03 | 0 |
| dusty-routes | C | uploads | bookings | 153 of 153 | 1.70-1.76 | 3.18-3.31 | 0 |
| dusty-routes | C | uploads | client | 51 of 51 | 0.28-0.34 | 0.60-1.66 | 0 |
| dusty-routes | C | uploads | encounter | 204 of 204 | 0.35-0.39 | 1.89-2.75 | 0 |
| dusty-routes | C | uploads | history | 204 of 204 | 0.43-0.47 | 1.85-2.45 | 0 |
| dusty-routes | C | uploads | poll | 934 of 935 | 0.30-0.33 | 2.28-2.66 | 0 |
| dusty-routes | C | uploads | shifts | 153 of 153 | 0.34-0.37 | 0.73-2.44 | 0 |

| Server | Tier | Run | CPU µs/req | uploads/s |
|---|---|---|---:|---:|
| hyper | C | alone | 155.0-158.9 |  |
| actix-web | C | alone | 155.8-156.6 |  |
| axum | C | alone | 143.3-144.0 |  |
| dusty | C | alone | 195.9-197.8 |  |
| dusty-routes | C | alone | 203.3-205.2 |  |
| hyper | C | uploads | 2120.0-2149.3 | 1.1K-1.2K |
| actix-web | C | uploads | 2328.1-2342.6 | 1.1K |
| axum | C | uploads | 2151.5-2208.6 | 1.1K |
| dusty | C | uploads | 2355.3-2363.5 | 1.0K |
| dusty-routes | C | uploads | 2351.6-2366.1 | 1.1K-1.2K |

