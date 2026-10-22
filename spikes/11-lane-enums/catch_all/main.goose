// Spike 11: a catch-all run beside a lane's cases, with one enum per lane.
// An overload that takes the lane's whole enum, untyped or typed, is an
// exact match, so it still takes every job, and the cases never run;
// nothing in the language flags it. A lane's loop can still notice a run
// that returned without replying, as the package's plod::lane does. See
// ../README.md.
import std;

enum Writes { Create { project: i64 }, Close { id: i64 } }
struct Writer { rows: i64 }

// What a lane's run gets, as the package's plod::Asked: the job, and
// whether run replied.
struct Took<U> { job: U, replied: bool = false }

fn done(a, v) {
    a.replied = true;
    print("  reply ", v);
}

// The package's lane loop for one job: F(u, a), then 500 no_reply when F
// returned without replying.
fn lane_once<U, F>(job: U) {
    var a = Took<U> { job: job };
    F(a.job, &a);
    if !a.replied { print("  no_reply: the lane answers 500 for ", job); }
}

// The cases alone: the writer runs its own variants, and no other lane's.
fn run(u: Writes.Create, w: Writer&, a) { w.rows++; done(a, u.project); }
fn run(u: Writes.Close, w: Writer&, a) { done(a, u.id); }

// The cases and an untyped catch-all.
fn untyped(u, w: Writer&, a) {}
fn untyped(u: Writes.Create, w: Writer&, a) { w.rows++; done(a, u.project); }
fn untyped(u: Writes.Close, w: Writer&, a) { done(a, u.id); }

// The cases and a catch-all typed with the lane's enum.
fn typed(u: Writes, w: Writer&, a) {}
fn typed(u: Writes.Create, w: Writer&, a) { w.rows++; done(a, u.project); }
fn typed(u: Writes.Close, w: Writer&, a) { done(a, u.id); }

fn main() {
    let jobs: Writes[] = [Writes.Create { project: 3 }, Writes.Close { id: 9 }];
    var w = Writer { rows: 0 };
    print("cases alone:");
    for j in jobs { lane_once(j) { u, a => run(u, w, a); }; }
    print("  rows written: ", w.rows);
    w.rows = 0;
    print("untyped catch-all:");
    for j in jobs { lane_once(j) { u, a => untyped(u, w, a); }; }
    print("  rows written: ", w.rows);
    print("typed catch-all:");
    for j in jobs { lane_once(j) { u, a => typed(u, w, a); }; }
    print("  rows written: ", w.rows);
}
