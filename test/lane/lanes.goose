// Lanes (lane.goose): a lane's thread count from its bounds and a placement,
// a job to the least busy thread and one by key to the same thread each time,
// in the order sent, and a stop that ends every thread with the jobs queued
// before it taken.
import std;
import os;
import http from "github.com/kaitk/goose-http@81bbf9baa315ad3607cd2a3a67fa7d14d154726c";
import rest from "../../";

let JOB: i32 = 1;
// No placement file: every lane has the code's count.
let NOWHERE = http::Place { .. };

// A lane thread: counts its jobs, and the jobs of each key it takes, and puts
// both in the queue for main once its box is stopped. A job's bytes, when it
// has a key, are the key and its number among that key's jobs.
struct Count { thread: i64, jobs: i64, keys: i64[..4], unordered: i64 }

// What a holding counter puts in the queue once it holds its first job, and
// what main puts there to let it go on.
struct Holding { thread: i64 }
struct Release { thread: i64 }

thread_fn counter(box: http::Box, id: i64, hold: bool) {
    var c = Count { thread: id, keys: [0, 0, 0, 0], .. };
    var last: i64[..4] = [-1, -1, -1, -1];
    rest::lane(box) { tag, bytes =>
        if hold && c.jobs == 0 {
            qput(Holding { thread: id });
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

fn counts(n: i64) -> Count[>..] {
    var all: Count[>..] = [];
    for i in n { all.push(Count { .. }); }
    for i in n {
        let c = qget<Count>();
        all[c.thread] = c;
    }
    return all;
}

fn close_all(l: const rest::Lane&) {
    rest::lane_stop(l);
    for b in l.boxes { http::mail_close(b); }
}

fn test_bounds() {
    let p, err = http::place_parse("reports = 8\nhasher = 3\nbig = 100\n", "lanes.place");
    assert(err.len == 0);
    // No file: the code's count. A file within max, and above it, cut.
    let none = rest::lane_open(NOWHERE, rest::LaneConfig { role: "reports", threads: 2, max: 8, .. });
    let within = rest::lane_open(p, rest::LaneConfig { role: "reports", threads: 2, max: 8, .. });
    let cut = rest::lane_open(p, rest::LaneConfig { role: "hasher", max: 2, .. });
    let writer = rest::lane_open(p, rest::LaneConfig { role: "writer", .. });
    print("threads: ", none.boxes.len, " with no file, ", within.boxes.len, " as the file says, ",
          cut.boxes.len, " cut to max, ", writer.boxes.len, " by default");
    // A max below threads is threads; threads below 1 is 1, with or without
    // a file; and no lane has more than LANE_MOST, from a file or the code.
    let below = rest::lane_open(p, rest::LaneConfig { role: "reports", threads: 4, max: 2, .. });
    let zero = rest::lane_open(p, rest::LaneConfig { role: "hasher", threads: 0, .. });
    let negative = rest::lane_open(NOWHERE, rest::LaneConfig { role: "writer", threads: -3, .. });
    let big = rest::lane_open(p, rest::LaneConfig { role: "big", threads: 2, max: 100, slots: 2, size: 16 });
    let code = rest::lane_open(NOWHERE, rest::LaneConfig { role: "code", threads: 100, slots: 2, size: 16 });
    print("threads: ", below.boxes.len, " with max below threads, ", zero.boxes.len, " and ",
          negative.boxes.len, " with threads below 1, ", big.boxes.len, " and ", code.boxes.len,
          " for 100 asked");
    for l in [none, within, cut, writer, below, zero, negative, big, code] { close_all(l); }
}

// Two threads, the first holding its job until main lets it go: the least
// busy box takes each job, so the idle thread, which main lets take each job
// before it sends the next, takes all of them, and none waits behind the
// held one.
fn test_least_busy() {
    let lane = rest::lane_open(NOWHERE, rest::LaneConfig { threads: 2, slots: 8, .. });
    let held = thread_spawn(counter, lane.boxes[0], 0, true);
    assert(http::mail_send(http::address(lane.boxes[0], 0), JOB, "") == http::SENT);
    qget<Holding>();
    let idle = thread_spawn(counter, lane.boxes[1], 1, false);
    let idle_at = http::address(lane.boxes[1], 0);
    var sent = 0;
    for i in 12 {
        while http::mail_queued(idle_at) != 0 { sleep_ms(1); }
        if rest::lane_send(lane, JOB, "") == http::SENT { sent++; }
    }
    qput(Release { thread: 0 });
    rest::lane_stop(lane);
    thread_wait(held);
    thread_wait(idle);
    let c = counts(2);
    print("least busy: ", sent, " of 12 sent, ", c[1].jobs, " to the idle thread, ", c[0].jobs, " to the held one");
}

// By key: every job of a key reaches the same thread, in the order sent.
fn test_by_key() {
    let lane = rest::lane_open(NOWHERE, rest::LaneConfig { threads: 3, slots: 64, .. });
    var ids: i64[>..] = [];
    for b, i in lane.boxes { ids.push(thread_spawn(counter, b, i, false)); }
    for i in 30 {
        let key = (i % 4) as u64;
        var job: u8[..2] = [];
        job.push(key as! u8);
        job.push((i / 4) as! u8);
        assert(rest::lane_send_by(lane, key, JOB, job) == http::SENT);
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
    print("by key: ", spread, " of 4 keys each on one thread, ", c[0].jobs + c[1].jobs + c[2].jobs, " jobs, ",
          c[0].unordered + c[1].unordered + c[2].unordered, " out of order");
    assert(rest::lane_send(lane, JOB, "") == http::STALE);
}

fn main() {
    test_bounds();
    test_least_busy();
    test_by_key();
}
