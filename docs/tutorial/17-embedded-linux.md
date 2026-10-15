# 17. Embedded Linux

goose-rest is Goose with no C of its own, so a program cross-builds for an embedded Linux
board as goose-http's do, with `goose build --cc` and the board's C cross compiler.
goose-http's [embedded Linux guide](https://github.com/kaitk/goose-http/blob/main/docs/embedded.md)
covers distribution cross compilers, Yocto SDKs, what the board needs, and the checks to
run on it.

[`examples/device`](../../examples/device/) is a board's API from a schema: temperature
and uptime from sysfs and `/proc`, settings whose bounds the schema checks and that set
an LED's brightness through sysfs, a firmware upload, a bearer token on writes, CORS,
and a page. It runs on one worker with small limits:

```rust
    let cfg = http::Config {
        port: port as i32, workers: 1, max_body: api::MAX_BODY,
        max_conns: 64, ring_entries: 256, ring_buffers: 64, ..
    };
```

The environment names the hardware (`THERMAL`, `LED`, `UPTIME`), so the example also runs
on a laptop, and its test fakes sysfs in files. `scripts/test-aarch64.sh` cross-builds
every example for aarch64 in an amd64 container and runs their checks in an arm64 one,
printing each one's peak RSS:

```sh
scripts/test-aarch64.sh
```

There, `examples/device` peaked at 4,728 kB on one worker. None has run on a board yet.
[Development](../development.md#run-the-examples-on-arm64) covers the setup and how
that was measured.

---

[Index](README.md) · Previous: [16. Testing the application](16-testing.md)
