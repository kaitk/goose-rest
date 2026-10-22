// Spike 11: how much a connection's request state takes with one enum per
// lane, measured as spike 10's sizes/main.goose does, beside its rows: the
// lane's mark alone, an outer enum holding each lane's job, and a field per
// lane. And what the reply carries back of the job. Sizes are of the packed
// layout (spec C.2), from bytes_of a one-element array.
import std;
import http from "github.com/kaitk/goose-http@5701a0d83a2f6e381bc13b69d80ae0a33d42daef";
import rest from "../../../";

// Spike 10's states: docs/best-practices/lanes/app.goose's steps, the one
// Use with the sign-in's text, and the same without it.
enum Waiting { None, EntryCreate, ReportTotals, AuthPassword, AuthSession }
struct WaitingSt { waiting: Waiting = Waiting.None }

enum Use10 {
    None,
    EntryCreate { project: i64, started: i64, stopped: i64 },
    ReportTotals { project: i64 },
    AuthPassword { email: u8[..64], password: u8[..64] },
    AuthSession { user: i64 },
}
struct Use10St { use: Use10 = Use10.None }

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

// Spike 11's lanes, as ../app.goose has them.
enum Writes {
    EntryCreate { project: i64, started: i64, stopped: i64 },
    AuthSession { user: i64 },
}
enum Reports { ReportTotals { project: i64 } }
enum Hashes { AuthPassword { email: u8[..64], password: u8[..64] } }

// The lane's mark alone, as ../app.goose's Use.
enum Use { None, Write, Report, Hash }
struct MarkSt { use: Use = Use.None }

// An outer enum holding each lane's job (../outer/main.goose).
enum Outer { None, Write { job: Writes }, Report { job: Reports }, Hash { job: Hashes } }
struct OuterSt { use: Outer = Outer.None }

// A field per lane, each lane's enum with a None of its own.
enum WritesOrNone {
    None,
    EntryCreate { project: i64, started: i64, stopped: i64 },
    AuthSession { user: i64 },
}
enum ReportsOrNone { None, ReportTotals { project: i64 } }
enum HashesOrNone { None, AuthPassword { email: u8[..64], password: u8[..64] } }
struct FieldsSt { w: WritesOrNone = WritesOrNone.None, r: ReportsOrNone = ReportsOrNone.None,
                  h: HashesOrNone = HashesOrNone.None }

// The fields goose-http's RingConn holds beside its Exchange, with each
// slice as C.2 lays it out, a pointer and a length: bytes_of refuses a
// slice.
struct RingFields { fd: i32, tag: u64, state: u8, queued: i64, reading: bool, stalled: bool, deadline: i64,
                    held_data: u64, held_len: i64 }

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

// What a lane's job costs in the mail: the Ask's image on the lane's box,
// and what the reply carries back before the answer, the job's image and
// its two-byte length.
fn mail<U>(name: const u8[:]) {
    print(name, ": Ask image ", to_bytes([rest::Ask<U> { job: default<U>() }]).len,
          " bytes, echo ", 2 + rest::value_bytes(default<U>()).len, " bytes");
}

fn main() {
    row("tier M (NoState)", rest::NoState { .. });
    row("tiers C and D (Heavy)", Heavy { .. });
    row("lanes, Waiting", WaitingSt { .. });
    row("spike 10, Use with the sign-in's text", Use10St { .. });
    row("spike 10, Use with ids only", IdsSt { .. });
    row("spike 11, the lane's mark", MarkSt { .. });
    row("spike 11, an outer enum holding the job", OuterSt { .. });
    row("spike 11, a field per lane", FieldsSt { .. });
    mail<Use10>("spike 10's Use");
    mail<Writes>("Writes");
    mail<Reports>("Reports");
    mail<Hashes>("Hashes");
}
