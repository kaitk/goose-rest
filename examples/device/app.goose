// The handlers api_gen.goose's dispatch calls, one per operationId in
// api.json, and the security check its token scheme names. The hardware is
// sysfs, read and written as files.
namespace app;

import std;
import os;
import base64;
import http;
import rest;
import api_gen;

// Where the hardware is, and the token the writes need. Flat, so it crosses
// to the worker thread.
struct Board {
    thermal: u8[..128] = "/sys/class/thermal/thermal_zone0",
    led: u8[..128] = "",
    uptime: u8[..128] = "/proc/uptime",
    token: u8[..128] = "secret",
}

// The worker's state, dispatch's state: the settings by reference, so that
// a change outlives the request.
struct App { board: Board, settings: api::Settings& }

let PAGE = embed_file("index.html");

// The security scheme token: a bearer token, which must be the board's.
fn security_token(cx, state: App&) -> bool {
    guard rest::bearer_token(cx) == state.board.token else { rest::invalid_token(cx); }
    return true;
}

fn page(cx, state: App&) {
    http::start(cx.out, 200);
    http::finish(cx.out, "Content-Type: text/html; charset=utf-8\r\nContent-Length: ", PAGE);
}

fn health(cx, state: App&) { rest::text(cx, 200, "ok"); }

fn get_status(cx, state: App&) {
    let temp, has_temp = read_value(str(state.board.thermal, "/temp"));
    let up, has_up = read_value(state.board.uptime);
    rest::json(cx, 200, api::Status {
        name: state.settings.name,
        temp_mc_null: !has_temp,
        temp_mc: temp,
        uptime_s_null: !has_up,
        uptime_s: up,
    });
}

fn get_settings(cx, state: App&) { rest::json(cx, 200, state.settings); }

// Sets the LED's brightness, when the board names one, before keeping the
// settings.
fn put_settings(cx, state: App&, s: bool, body: const api::Settings&) {
    if state.board.led.len > 0 {
        var level: u8[..24] = [];
        format(level, body.brightness);
        guard write_file(str(state.board.led, "/brightness"), level) else { rest::fail(cx, 500, "led_unavailable"); }
    }
    state.settings = body;
    rest::json(cx, 200, state.settings);
}

// Checks an image and answers its size and CRC-32. The example keeps no
// image.
fn put_firmware(cx, state: App&, s: bool, body: const api::FirmwareUpload&) {
    var image: u8[>..] = [];
    guard base64::decode(image, body.image) else { rest::fail(cx, 400, "image_not_base64"); }
    var hex: u8[..32] = [];
    let c = crc32(image);
    for i in 8 { hex.push("0123456789abcdef"[(c >> ((7 - i) * 4)) & 15]); }
    rest::json(cx, 200, api::Firmware { version: body.version, bytes: image.len, crc32: hex });
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
