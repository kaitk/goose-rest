// Lanes (lane.goose): a lane's thread count from its bounds and a placement,
// a job to the least busy thread and one by key to the same thread each time,
// in the order sent, and a stop that ends every thread with the jobs queued
// before it taken, and waits for them.
import std;
import os;
import http from "github.com/kaitk/goose-http@81bbf9baa315ad3607cd2a3a67fa7d14d154726c";
import rest from "../../";

let JOB: i32 = 1;
// A job its thread holds until main lets it go.
let HOLD: i32 = 2;
// No placement file: every lane has the code's count.
let NOWHERE = http::Place { .. };

// A lane thread: counts its jobs, and the jobs of each key it takes, and puts
// both in the queue for main, with its box's slot, once its box is stopped.
// A job's bytes, when it has a key, are the key and its number among that
// key's jobs.
struct Count { slot: i32, jobs: i64, keys: i64[..4], unordered: i64 }

// What a thread puts in the queue once it holds a HOLD job, and what main
// puts there to let it go on.
struct Holding { slot: i32 }
struct Release { slot: i32 }

thread_fn counter(box: http::Box, at: http::Seat) {
    var c = Count { slot: box.handle.slot, keys: [0, 0, 0, 0], .. };
    var last: i64[..4] = [-1, -1, -1, -1];
    rest::lane(box) { tag, bytes =>
        if tag == HOLD {
            qput(Holding { slot: c.slot });
            qget<Release>();
        }
        c.jobs++;
        if bytes.len == 2 {
            let k = bytes[0] as i64;
            let n = bytes[1] as i64;
            if n <= last[k] { c.unordered++; }
            last[k] = n;
            c.keys[k]++;
        }
    };
    qput(c);
}

thread_fn idle(box: http::Box, at: http::Seat) {
    rest::lane(box) { tag, bytes => {} };
}

// What each of lane's threads counted, in the order of its boxes.
fn counts(lane: const rest::Lane&) -> Count[>..] {
    var all: Count[>..] = [];
    for b in lane.boxes { all.push(Count { .. }); }
    for k in lane.boxes.len {
        let c = qget<Count>();
        for b, i in lane.boxes { if b.handle.slot == c.slot { all[i] = c; } }
    }
    return all;
}

// The threads a lane of cfg gets from p.
fn threads(p: const http::Place&, cfg: rest::LaneConfig) -> i64 {
    let lane = rest::lane_open(p, cfg, idle);
    rest::lane_stop(lane);
    return lane.threads.len;
}

fn test_bounds() {
    let p, err = http::place_parse("reports = 8\nhasher = 3\nbig = 100\n", "lanes.place");
    assert(err.len == 0);
    // No file: the code's count. A file within max, and above it, cut.
    print("threads: ", threads(NOWHERE, rest::LaneConfig { role: "reports", threads: 2, max: 8, .. }), " with no file, ",
          threads(p, rest::LaneConfig { role: "reports", threads: 2, max: 8, .. }), " as the file says, ",
          threads(p, rest::LaneConfig { role: "hasher", max: 2, .. }), " cut to max, ",
          threads(p, rest::LaneConfig { role: "writer", .. }), " by default");
    // A max below threads is threads; threads below 1 is 1, with or without
    // a file; and no lane has more than LANE_MOST, from a file or the code.
    print("threads: ", threads(p, rest::LaneConfig { role: "reports", threads: 4, max: 2, .. }), " with max below threads, ",
          threads(p, rest::LaneConfig { role: "hasher", threads: 0, .. }), " and ",
          threads(NOWHERE, rest::LaneConfig { role: "writer", threads: -3, .. }), " with threads below 1, ",
          threads(p, rest::LaneConfig { role: "big", threads: 2, max: 100, slots: 2, size: 16 }), " and ",
          threads(NOWHERE, rest::LaneConfig { role: "code", threads: 100, slots: 2, size: 16 }), " for 100 asked");
}

// Two threads, the first holding its job until main lets it go: the least
// busy box takes each job, so the idle thread, which main lets take each job
// before it sends the next, takes all of them, and none waits behind the
// held one.
fn test_least_busy() {
    let lane = rest::lane_open(NOWHERE, rest::LaneConfig { threads: 2, slots: 8, .. }, counter);
    assert(http::mail_send(http::address(lane.boxes[0], 0), HOLD, "") == http::SENT);
    let held = qget<Holding>();
    let idle_at = http::address(lane.boxes[1], 0);
    var sent = 0;
    for i in 12 {
        while http::mail_queued(idle_at) != 0 { sleep_ms(1); }
        if rest::lane_send(lane, JOB, "") == http::SENT { sent++; }
    }
    qput(Release { slot: held.slot });
    rest::lane_stop(lane);
    let c = counts(lane);
    print("least busy: ", sent, " of 12 sent, ", c[1].jobs, " to the idle thread, ", c[0].jobs, " to the held one");
}

// By key: every job of a key reaches the same thread, in the order sent.
fn test_by_key() {
    let lane = rest::lane_open(NOWHERE, rest::LaneConfig { threads: 3, slots: 64, .. }, counter);
    for i in 30 {
        let key = (i % 4) as u64;
        var job: u8[..2] = [];
        job.push(key as! u8);
        job.push((i / 4) as! u8);
        assert(rest::lane_send_by(lane, key, JOB, job) == http::SENT);
    }
    rest::lane_stop(lane);
    let c = counts(lane);
    var spread = 0;
    for k in 4 {
        var holders = 0;
        for t in c { if t.keys[k] > 0 { holders++; } }
        if holders == 1 { spread++; }
    }
    print("by key: ", spread, " of 4 keys each on one thread, ", c[0].jobs + c[1].jobs + c[2].jobs, " jobs, ",
          c[0].unordered + c[1].unordered + c[2].unordered, " out of order");
    assert(rest::lane_send(lane, JOB, "") == http::STALE);
}

fn main() {
    test_bounds();
    test_least_busy();
    test_by_key();
}
