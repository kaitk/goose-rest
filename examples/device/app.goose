// The handlers api_gen.goose's dispatch calls, one per operationId in
// api.json, and the security check its token scheme names. The hardware is
// sysfs, read and written as files.
namespace app;

import std;
import os;
import base64;
import http;
import plod;
import api_gen;

// Where the hardware is, and the token the writes need. Flat, so it crosses
// to the worker thread. 1 KB a path, since the tests put the fake sysfs under
// the checkout, whose path can be long.
struct Board {
    thermal: u8[..1024] = "/sys/class/thermal/thermal_zone0",
    led: u8[..1024] = "",
    uptime: u8[..1024] = "/proc/uptime",
    token: u8[..1024] = "secret",
}

// The worker state, cx.app: the settings by reference, so that a change
// outlives the request.
struct App { board: Board, settings: api::Settings& }

let PAGE = embed_file("index.html");

// The security scheme token: a bearer token, which must be the board's.
fn security_token(cx) -> bool {
    guard plod::bearer_token(cx) == cx.app.board.token else { plod::invalid_token(cx); }
    return true;
}

fn page(cx) {
    http::start(cx.out, 200);
    http::finish(cx.out, "Content-Type: text/html; charset=utf-8\r\nContent-Length: ", PAGE);
}

fn health(cx) { plod::text(cx, 200, "ok"); }

fn get_status(cx) {
    let temp, has_temp = read_value(str(cx.app.board.thermal, "/temp"));
    let up, has_up = read_value(cx.app.board.uptime);
    plod::json(cx, 200, api::Status {
        name: cx.app.settings.name,
        temp_mc_null: !has_temp,
        temp_mc: temp,
        uptime_s_null: !has_up,
        uptime_s: up,
    });
}

fn get_settings(cx) { plod::json(cx, 200, cx.app.settings); }

// Sets the LED's brightness, when the board names one, before keeping the
// settings.
fn put_settings(cx,s: bool, body: const api::Settings&) {
    if cx.app.board.led.len > 0 {
        var level: u8[..24] = [];
        format(level, body.brightness);
        guard write_file(str(cx.app.board.led, "/brightness"), level) else { plod::fail(cx, 500, "led_unavailable"); }
    }
    cx.app.settings = body;
    plod::json(cx, 200, cx.app.settings);
}

// Checks an image and answers its size and CRC-32. The example keeps no
// image.
fn put_firmware(cx,s: bool, body: const api::FirmwareUpload&) {
    var image: u8[>..] = [];
    guard base64::decode(image, body.image) else { plod::fail(cx, 400, "image_not_base64"); }
    var hex: u8[..32] = [];
    let c = crc32(image);
    for i in 8 { hex.push("0123456789abcdef"[(c >> ((7 - i) * 4)) & 15]); }
    plod::json(cx, 200, api::Firmware { version: body.version, bytes: image.len, crc32: hex });
}

// CRC-32 (IEEE 802.3), bit by bit: an image is read once, and a table would
// cost a board 1 KB for little.
fn crc32(data: const u8[:]) -> i64 {
    var c: i64 = 0xFFFFFFFF;
    for b in data {
        c ^= b;
        for k in 8 { c = if (c & 1) != 0 { (c >> 1) ^ 0xEDB88320 } else { c >> 1 }; }
    }
    return c ^ 0xFFFFFFFF;
}

// The number at the start of the file at path, up to a '.' or a space: a
// sysfs value, or /proc/uptime's seconds.
fn read_value(path: const u8[:]) -> i64, bool {
    var text: u8[>..] = [];
    guard read_file(path, text) else { return 0, false; }
    var n = 0;
    while n < text.len && text[n] != '.' && text[n] != ' ' && text[n] != '\n' { n++; }
    return parse_int(text[..n]);
}
