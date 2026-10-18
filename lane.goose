// Lanes: threads that do a route's slow work, each with a box of its own. A
// lane is the threads of one role, such as a database's readers. The code
// gives each lane its bounds in a LaneConfig, and a placement file
// (http::place_load) may give it any count up to max and say where its
// threads run. lane_open spawns them:
//
//   let place = http::place_load();
//   let reports = rest::lane_open(place, rest::LaneConfig { role: "reports", threads: 2, max: 8, .. }, reader);
//
//   thread_fn reader(box: http::Box, at: http::Seat) {
//       http::take_seat(at);            // first, before its own memory
//       rest::lane(box) { tag, bytes => ... };
//   }
//
// A route asks the lane with rest::ask, which takes its least busy thread,
// or with rest::ask_by, which takes the thread a key picks in a run, so that
// one key's jobs run in order. rest::lane_stop stops every thread once the
// workers are done, and waits for them.
namespace rest;

import std;
import http from "github.com/kaitk/goose-http@81bbf9baa315ad3607cd2a3a67fa7d14d154726c";

// A lane's bounds, in code: its role in a placement file, its threads where
// the file gives no count (at least 1), the most a file may give (0, or
// below threads: threads; never above LANE_MOST), and each box's slots, a
// power of two of at least 2, and slot size. A count above the most is cut
// to it with a warning.
struct LaneConfig {
    role: u8[..32] = "",
    threads: i64 = 1,
    max: i64 = 0,
    slots: i32 = 64,
    size: i32 = 256,
}

// The most threads one lane has.
let LANE_MOST: i64 = 64;

// A lane's boxes, and its threads' ids, one of each per thread. Flat, so
// that it crosses thread_spawn in an application's state.
struct Lane { boxes: http::Box[..64], threads: i64[..64] }

// Where this thread's next lane_send starts its scan. Each thread has its
// own copy of a global, so it needs no synchronization.
var lane_turn: i64 = 0;

// Opens a lane of cfg's role, as many threads as place gives it within cfg's
// bounds, or cfg.threads, each the thread_fn W with a box of its own, the
// seat place gives it, and a, where given. A box that fails to open ends the
// program, as a configuration that can't start does.
//
//   rest::lane_open(place, cfg, reader);       // thread_fn reader(box: http::Box, at: http::Seat)
//   rest::lane_open(place, cfg, db, reader);   // thread_fn reader(box: http::Box, at: http::Seat, db: Db)
fn lane_open<W>(place: const http::Place&, cfg: LaneConfig) -> Lane {
    return lane_spawn(place, cfg) { b, at => thread_spawn(W, b, at) };
}
fn lane_open<W>(place: const http::Place&, cfg: LaneConfig, a) -> Lane {
    return lane_spawn(place, cfg) { b, at => thread_spawn(W, b, at, a) };
}

// lane_open's work: SPAWN starts a thread with its box and seat and returns
// its id.
fn lane_spawn<SPAWN>(place: const http::Place&, cfg: LaneConfig) -> Lane {
    let t = max(cfg.threads, 1);
    let most = min(if cfg.max > 0 { max(cfg.max, t) } else { t }, LANE_MOST);
    var n = http::place_threads(place, cfg.role, t, most);
    // place_threads doesn't check the count of a role the file doesn't name.
    if n > most {
        write_stderr(str("lane ", cfg.role, ": ", n, " threads cut to the most, ", most, "\n"));
        n = most;
    }
    var lane = Lane { .. };
    for i in n {
        let b, e = http::mail_open(cfg.slots, cfg.size);
        http::exit_on_error(e);
        lane.boxes.push(b);
        lane.threads.push(SPAWN(b, http::place_seat(place, cfg.role, i)));
    }
    return lane;
}

// Stops every thread of lane, each of which takes what its box holds and
// returns from rest::lane, and waits for them. A full box can't refuse the
// stop. The thread that opened the lane calls it, once the workers are done.
fn lane_stop(lane: const Lane&) {
    for b in lane.boxes { http::mail_stop(b); }
    for id in lane.threads { thread_wait(id); }
}

// A lane thread's loop: F with each job's tag and bytes, in the order they
// came, until the box is stopped and empty; then closes the box.
fn lane<F>(box: http::Box) {
    while !http::mail_stopped(box) {
        // No time limit: a stop wakes this wait too.
        http::mail_wait(box, -1);
        http::mail_take(box) { key, tag, bytes => F(tag, bytes); };
    }
    http::mail_close(box);
}

// Sends image with tag to the least busy of lane's boxes, the one holding
// the fewest jobs, and to the others in turn while each is full. Returns
// SENT, FULL when every box is, TOO_LONG, or STALE.
fn lane_send(lane: const Lane&, tag: i32, image: const u8[:]) -> i32 {
    let n = lane.boxes.len;
    guard n > 0 else { return http::STALE; }
    // Each send starts the scan one box further on, so that ties don't all
    // go to one box and senders don't all read the same box's counts first.
    let start = lane_turn % n;
    lane_turn++;
    var best = start;
    var least: i64 = -1;
    for k in n {
        let i = (start + k) % n;
        let q = http::mail_queued(http::address(lane.boxes[i], 0));
        if q >= 0 && (least < 0 || q < least) {
            least = q;
            best = i;
            if q == 0 { break; }
        }
    }
    var r = http::STALE;
    for k in n {
        let sent = http::mail_send(http::address(lane.boxes[(best + k) % n], 0), tag, image);
        if sent == http::SENT || sent == http::TOO_LONG { return sent; }
        if sent == http::FULL { r = sent; }
    }
    return r;
}

// Sends image with tag to the box of lane that key always picks within one
// run: the pick follows the lane's thread count, which a placement file can
// change between runs.
fn lane_send_by(lane: const Lane&, key: u64, tag: i32, image: const u8[:]) -> i32 {
    let n = lane.boxes.len;
    guard n > 0 else { return http::STALE; }
    return http::mail_send(http::address(lane.boxes[(key % (n as u64)) as! i64], 0), tag, image);
}
