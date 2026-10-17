// Lanes (lane.goose): a lane's thread count from its bounds and a placement,
// a job to the least busy thread and one by key to the same thread each time,
// and a stop that ends every thread with the jobs queued before it taken.
import std;
import os;
import http from "github.com/kaitk/goose-http@782ec236b44bdc5da5a4ea289115095268d6696e";
import rest from "../../";

let JOB: i32 = 1;
// No placement file: every lane has the code's count.
let NOWHERE = http::Place { .. };

// A lane thread: counts its jobs, and the jobs of each key it takes, and puts
// both in the queue for main once its box is stopped.
struct Count { thread: i64, jobs: i64, keys: i64[..4] }

thread_fn counter(box: http::Box, id: i64, hold_ms: i64) {
    var c = Count { thread: id, keys: [0, 0, 0, 0], .. };
    rest::lane(box) { tag, bytes =>
        if hold_ms > 0 { sleep_ms(hold_ms); }
        c.jobs++;
        if bytes.len == 1 { c.keys[bytes[0] as i64]++; }
    };
    qput(c);
}

fn counts(n: i64) -> Count[>..] {
    var all: Count[>..] = [];
    for i in n { all.push(Count { .. }); }
    for i in n {
        let c = qget<Count>();
        all[c.thread] = c;
    }
    return all;
}

fn test_bounds() {
    let p, err = http::place_parse("reports = 8\nhasher = 3\n", "lanes.place");
    assert(err.len == 0);
    // No file: the code's count. A file within max, and above it, cut.
    let none = rest::lane_open(NOWHERE, rest::LaneConfig { role: "reports", threads: 2, max: 8, .. });
    let within = rest::lane_open(p, rest::LaneConfig { role: "reports", threads: 2, max: 8, .. });
    let cut = rest::lane_open(p, rest::LaneConfig { role: "hasher", max: 2, .. });
    let writer = rest::lane_open(p, rest::LaneConfig { role: "writer", .. });
    print("threads: ", none.boxes.len, " with no file, ", within.boxes.len, " as the file says, ",
          cut.boxes.len, " cut to max, ", writer.boxes.len, " by default");
    for l in [none, within, cut, writer] {
        rest::lane_stop(l);
        for b in l.boxes { http::mail_close(b); }
    }
}

// Two threads, the first busy for 200 ms: the least busy box takes each job,
// so the idle thread, which takes each job before the next comes 5 ms later,
// takes all of them, and none waits behind the busy one.
fn test_least_busy() {
    let lane = rest::lane_open(NOWHERE, rest::LaneConfig { threads: 2, slots: 8, .. });
    let busy = thread_spawn(counter, lane.boxes[0], 0, 200);
    assert(rest::lane_send(lane, JOB, "") == http::SENT);
    sleep_ms(50);
    let idle = thread_spawn(counter, lane.boxes[1], 1, 0);
    var sent = 0;
    for i in 12 {
        if rest::lane_send(lane, JOB, "") == http::SENT { sent++; }
        sleep_ms(5);
    }
    rest::lane_stop(lane);
    thread_wait(busy);
    thread_wait(idle);
    let c = counts(2);
    print("least busy: ", sent, " of 12 sent, ", c[1].jobs, " to the idle thread, ", c[0].jobs, " to the busy one");
}

// By key: every job of a key reaches the same thread.
fn test_by_key() {
    let lane = rest::lane_open(NOWHERE, rest::LaneConfig { threads: 3, slots: 64, .. });
    var ids: i64[>..] = [];
    for b, i in lane.boxes { ids.push(thread_spawn(counter, b, i, 0)); }
    for i in 30 {
        let key = (i % 4) as u64;
        var one: u8[..1] = [];
        one.push(key as! u8);
        assert(rest::lane_send_by(lane, key, JOB, one) == http::SENT);
    }
    rest::lane_stop(lane);
    for id in ids { thread_wait(id); }
    let c = counts(3);
    var spread = 0;
    for k in 4 {
        var holders = 0;
        for t in c { if t.keys[k] > 0 { holders++; } }
        if holders == 1 { spread++; }
    }
    print("by key: ", spread, " of 4 keys each on one thread, ", c[0].jobs + c[1].jobs + c[2].jobs, " jobs");
    assert(rest::lane_send(lane, JOB, "") == http::STALE);
}

fn main() {
    test_bounds();
    test_least_busy();
    test_by_key();
}
