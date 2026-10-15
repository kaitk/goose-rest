# 17. Embedded Linux

goose-rest is written in Goose with no C of its own, so its programs cross-build for
embedded Linux boards in the same way as goose-http programs: with `goose build --cc`
and the board's C cross compiler. goose-http's
[embedded Linux guide](https://github.com/kaitk/goose-http/blob/main/docs/embedded.md)
covers distribution cross compilers, Yocto SDKs, board requirements, and checks to run
on the board.

[`examples/device`](../../examples/device/) defines a board API from a schema. It
provides temperature and uptime from sysfs and `/proc`, settings that control an LED's
brightness through sysfs and are validated against schema bounds, a firmware upload,
bearer-token protection for writes, CORS, and a web page. It runs on one worker with
small limits:

```rust
    let cfg = http::Config {
        port: port as i32, workers: 1, max_body: api::MAX_BODY,
        max_conns: 64, ring_entries: 256, ring_buffers: 64, ..
    };
```

Environment variables (`THERMAL`, `LED`, `UPTIME`) specify the hardware paths, so the
example also runs on a laptop; its test uses files to simulate sysfs.
`scripts/test-aarch64.sh` cross-builds every example for aarch64 in an amd64 container,
then runs the checks in an arm64 container and prints each example's peak RSS:

```sh
scripts/test-aarch64.sh
```

In that test, `examples/device` reached a peak RSS of 4,728 kB with one worker. None of
the examples has run on a board yet. [Development](../development.md#run-the-examples-on-arm64)
covers the setup and measurement method.

---

[Index](README.md) · Previous: [16. Testing the application](16-testing.md) · Next:
[Best practices](../best-practices/README.md)
