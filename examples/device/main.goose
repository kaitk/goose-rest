// A device's HTTP API, for an embedded Linux board, from a schema: api.json
// describes it, goose-rest gen writes api_gen.goose from it, and app.goose
// holds the handlers. The SoC's temperature and the uptime are read from
// sysfs and /proc, and PUT /v1/settings sets an LED's brightness through
// sysfs. The page at / shows them. One worker, which keeps the settings, and
// small limits: a board's memory is small. What it adds to goose-http's
// examples/device is the schema: the settings' bounds, the token scheme, and
// the upload's limit. Events over time and a GPIO line through C are there.
//
//   build/goose-rest gen examples/device/api.json -o examples/device/api_gen.goose
//   goose build -o build/examples/device examples/device/main.goose
//   LED=/sys/class/leds/user-led build/examples/device 8080
//   curl -s localhost:8080/v1/status
//   curl -s -X PUT -H 'Authorization: Bearer secret' -H 'Content-Type: application/json' \
//        -d '{"name": "porch", "brightness": 128, "interval_ms": 500}' localhost:8080/v1/settings
//
// The environment names the hardware, and the example runs without any:
//
//   THERMAL  a thermal zone's directory, /sys/class/thermal/thermal_zone0 by default
//   LED      an LED's directory, such as /sys/class/leds/user-led; without it, none
//   UPTIME   the uptime's file, /proc/uptime by default
//   TOKEN    the bearer token the writes need, secret by default
import std;
import os;
import http from "github.com/kaitk/goose-http@v0.4.1";
import rest from "../../";
import .api_gen;
import .app;

thread_fn worker(cfg: http::Config, b: app::Board) {
    var settings = api::Settings { name: "device", brightness: 0, interval_ms: 1000 };
    var app = app::App { board: b, settings: settings };
    let e = rest::serve(cfg, app) { cx =>
        rest::timed(cx) {
            rest::cors(cx, rest::Cors { origins: "https://fleet.example", methods: "GET, HEAD, PUT", .. }) {
                api::dispatch(cx);
            };
        };
    };
    if e.code != 0 { http::report(e); }
}

// The environment variable name into to, which it must fit.
fn setting(name: const u8[:], to: u8[..1024]&) {
    var v: u8[>..] = [];
    guard env(name, v) else { return; }
    guard v.len <= 1024 else { write_stderr(str(name, " is too long\n")); exit(2); }
    to.clear();
    to.append(v);
}

fn main() {
    let a = args();
    var port: i64 = 8080;
    if a.len > 1 {
        let p, ok = parse_int(a[1]);
        if ok { port = p; }
    }
    var b = app::Board { .. };
    setting("THERMAL", b.thermal);
    setting("LED", b.led);
    setting("UPTIME", b.uptime);
    setting("TOKEN", b.token);
    http::exit_on_error(http::stop_on_signals());
    let cfg = http::Config {
        port: port as i32, workers: 1, max_body: api::MAX_BODY,
        max_conns: 64, ring_entries: 256, ring_buffers: 64, ..
    };
    http::run(cfg, b, worker);
}
