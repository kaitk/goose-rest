// Spike 10's second question: how much a connection's request state grows
// when the use case's variant, the job, waits in cx.state. Sizes are of the
// packed layout (spec C.2), from bytes_of a one-element array.
import std;
import http from "github.com/kaitk/goose-http@v0.4.3";
import rest from "../../../";

// docs/best-practices/lanes/app.goose's state: steps, no payload.
enum Waiting { None, EntryCreate, ReportTotals, AuthPassword, AuthSession }
struct WaitingSt { waiting: Waiting = Waiting.None }

// The same four use cases as variants that carry their jobs, as in
// ../app.goose, and the same without the sign-in's text.
enum Use {
    None,
    EntryCreate { project: i64, started: i64, stopped: i64 },
    ReportTotals { project: i64 },
    AuthPassword { email: u8[..64], password: u8[..64] },
    AuthSession { user: i64 },
}
struct UseSt { use: Use = Use.None }

enum Ids {
    None,
    EntryCreate { project: i64, started: i64, stopped: i64 },
    ReportTotals { project: i64 },
    AuthSession { user: i64 },
}
struct IdsSt { use: Ids = Ids.None }

// Tiers C and D's state (bench/rest/goose-rest/main.goose).
enum Pieces { None, Import, Attachment }
struct Heavy { waiting: Pieces = Pieces.None, spool: i64 = -1 }

// The fields goose-http's RingConn and EpollConn hold beside their Exchange,
// with each slice as C.2 lays it out, a pointer and a length: bytes_of
// refuses a slice.
struct RingFields { fd: i32, tag: u64, state: u8, queued: i64, reading: bool, stalled: bool, deadline: i64,
                    held_data: u64, held_len: i64 }
struct EpollFields { fd: i32, state: u8, watch_out: bool, ready: bool, listed: bool, deadline: i64,
                     held_data: u64, held_len: i64, out_data: u64, out_len: i64 }

fn size(v) -> i64 {
    var one = [v];
    return bytes_of(one).len;
}

// A connection's bytes for request state S: S, goose-rest's Slot, and
// goose-http's Exchange and RingConn.
fn row<S>(name: const u8[:], fresh: S) {
    let slot = rest::Slot<S> { state: fresh };
    let ex = size(default<http::Exchange<rest::Slot<S>>>());
    let ring = ex + size(default<RingFields>());
    print(name, ": state ", size(fresh), ", Slot ", size(slot), ", Exchange ", ex, ", RingConn ", ring,
          "; ", ring, " KB per 1,000 connections");
}

fn main() {
    row("tier M (NoState)", rest::NoState { .. });
    row("tiers C and D (Heavy)", Heavy { .. });
    row("lanes, Waiting", WaitingSt { .. });
    row("lanes, Use with the sign-in's text", UseSt { .. });
    row("lanes, Use with ids only", IdsSt { .. });
    print("EpollConn's fields beside its Exchange: ", size(default<EpollFields>()));
    // A variant's constructor is of the variant's type, its payload alone.
    print("Use.EntryCreate { .. } ", size(Use.EntryCreate { project: 0, started: 0, stopped: 0 }),
          "; a Use holding it ", size(UseSt { use: Use.EntryCreate { project: 0, started: 0, stopped: 0 } }),
          "; u8[..64] ", size(default<u8[..64]>()));
    print("an Ask<Use> on a lane's box: ",
          size(rest::Ask<Use> { job: Use.None }), " bytes; its to_bytes image: ",
          to_bytes([rest::Ask<Use> { job: Use.None }]).len, " of a 256-byte slot");
}
