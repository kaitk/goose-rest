// rest::ask_by: a route's job reaches the box of the lane's thread that the key
// picks (key % threads), and no other.
import std;
import http from "github.com/kaitk/goose-http@81bbf9baa315ad3607cd2a3a67fa7d14d154726c";
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

// What a lane thread took, by its box's slot, once its box is stopped.
struct Took { slot: i32, jobs: i64, tags: i64 }

thread_fn taker(box: http::Box, at: http::Seat) {
    var t = Took { slot: box.handle.slot, .. };
    rest::lane(box) { tag, bytes =>
        t.jobs++;
        if tag == JOB { t.tags++; }
    };
    qput(t);
}

fn main() {
    let nowhere = http::Place { .. };
    let lane = rest::lane_open(nowhere, rest::LaneConfig { threads: 2, slots: 4, .. }, taker);
    var app = App { lane: lane };
    let out = rest::serve_one("GET / HTTP/1.1\r\n\r\n", app, St { .. }, []) { cx => handle(cx) };
    print("answer: ", out.len, " bytes");
    rest::lane_stop(lane);
    var took: Took[>..] = [];
    for b in lane.boxes { took.push(Took { .. }); }
    for k in lane.boxes.len {
        let t = qget<Took>();
        for b, i in lane.boxes { if b.handle.slot == t.slot { took[i] = t; } }
    }
    for t, i in took { print("box ", i, ": ", t.jobs, " job(s), ", t.tags, " with the tag"); }
    print("key ", KEY, " picks box ", KEY % (lane.boxes.len as u64));
}
