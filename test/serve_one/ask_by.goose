// rest::ask_by: a route's job reaches the box of the lane's thread that the key
// picks (key % threads), and no other.
import std;
import http from "github.com/kaitk/goose-http@746f9567b5a51ca725b7e7e55f86cce8da703a56";
import rest from "../../";

enum Waiting { None, Asked }

struct St { waiting: Waiting = Waiting.None }

struct App { lane: rest::Lane }

let JOB: i32 = 1;
let KEY: u64 = 7;

fn handle(cx) {
    if rest::resumed(cx) {
        rest::fail(cx, 500, "not_waiting");
    } else {
        rest::ask_by(cx, cx.app.lane, KEY, JOB, 42, Waiting.Asked, 200);
    }
}

fn main() {
    let nowhere = http::Place { .. };
    let lane = rest::lane_open(nowhere, rest::LaneConfig { threads: 2, slots: 4, .. });
    var app = App { lane: lane };
    let out = rest::serve_one("GET / HTTP/1.1\r\n\r\n", app, St { .. }, []) { cx => handle(cx) };
    print("answer: ", out.len, " bytes");
    for b, i in lane.boxes {
        var tags = 0;
        let n = http::mail_take(b) { key, tag, bytes => if tag == JOB { tags++; } };
        print("box ", i, ": ", n, " job(s), ", tags, " with the tag");
    }
    print("key ", KEY, " picks box ", KEY % (lane.boxes.len as u64));
    for b in lane.boxes { http::mail_close(b); }
}
