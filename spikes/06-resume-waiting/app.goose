// The application: two routes that wait on the database thread, the
// per-request state they keep, the case functions that resume them, and the
// database thread.
namespace app;

import std;
import os;
import http;

// A job's tag, and a reply's: whether more of it follows.
let REPORT: i32 = 1;
let EXPORT: i32 = 2;
let STOP: i32 = 3;
let MORE: i32 = 1;
let LAST: i32 = 2;

// The worker box's slots, as Config.mail_slots and Config.mail_size give them:
// small, so that the export takes more messages than the box has slots.
let SLOTS: i32 = 2;
let SLOT_SIZE: i32 = 64;

// Jobs and replies cross as to_bytes images of one-element arrays.
struct ReportJob { reply: http::MailAddress, org: i64, from: i64, to: i64 }
struct ReportReply { total: i64, days: i64 }
// piece: the most bytes a reply message may hold, the worker's slot size,
// which a sender can't learn from the address.
struct ExportJob { reply: http::MailAddress, org: i64, rows: i64, piece: i64 }

// What each waiting route needs when its answer comes. Fixed-mode: each
// request overwrites the slot (spec §3.5).
enum Waiting {
    None,
    Report { org: i64, from: i64, to: i64 },
    Export { org: i64, parts: i64, bytes: i64 },
}

// The per-request state, http::serve's S.
struct St { waiting: Waiting = Waiting.None }

// The database thread's box, which main sets before it spawns the workers,
// which copy it.
var db: http::MailAddress;

inline fn handle(ev: http::Event, st: St&, out: http::Reply) {
    match ev {
        Request r => route(r.req, st, out),
        Wake w => resume(st.waiting, st, w.data, w.tag, out),
        Timeout => http::respond(out, 504, "text/plain", "timeout"),
        _ => {},
    }
}

fn route(req: const http::Request&, st: St&, out: http::Reply) {
    let path = http::path_of(req.target);
    let org = query_int(req.target, "org");
    if path == "/report" {
        let from = query_int(req.target, "from");
        let to = query_int(req.target, "to");
        st.waiting = Waiting.Report { org: org, from: from, to: to };
        ask(out, REPORT, ReportJob { reply: http::later(out, 5000), org: org, from: from, to: to });
    } else if path == "/export" {
        st.waiting = Waiting.Export { org: org, parts: 0, bytes: 0 };
        ask(out, EXPORT, ExportJob { reply: http::later(out, 5000), org: org, rows: query_int(req.target, "rows"),
                                     piece: SLOT_SIZE });
    } else {
        http::respond(out, 404, "text/plain", "");
    }
}

// Sends job to the database thread, or answers 503.
fn ask(out: http::Reply, tag: i32, job) {
    var one = [job];
    let image = to_bytes(one);
    guard http::mail_send(db, tag, image) == http::SENT else {
        http::respond(out, 503, "text/plain", "busy");
        return;
    }
}

fn resume(w: Waiting.None, st: St&, data: const u8[:], tag: i32, out: http::Reply) {
    http::respond(out, 500, "text/plain", "not waiting");
}

fn resume(w: Waiting.Report, st: St&, data: const u8[:], tag: i32, out: http::Reply) {
    let rows, ok = from_bytes<ReportReply[>..]>(data);
    guard ok && rows.len == 1 else {
        http::respond(out, 502, "text/plain", "bad reply");
        return;
    }
    var body: u8[>..] = [];
    format(body, "{\"org\":", w.org, ",\"from\":", w.from, ",\"to\":", w.to, ",\"days\":", rows[0].days,
           ",\"total\":", rows[0].total, "}");
    http::respond(out, 200, "application/json", body);
}

// The reply comes in pieces of at most a slot each, MORE then LAST, and goes
// out as a chunked response, a chunk per piece.
fn resume(w: Waiting.Export, st: St&, data: const u8[:], tag: i32, out: http::Reply) {
    if w.parts == 0 {
        http::begin(out, 200, -1);
        http::field(out, "Content-Type", "text/csv");
    }
    http::send(out, data);
    st.waiting = Waiting.Export { org: w.org, parts: w.parts + 1, bytes: w.bytes + data.len };
    if tag == LAST { http::end(out); } else { http::later(out, 5000); }
}

fn query_int(target: const u8[:], key: const u8[:]) -> i64 {
    let v, has = http::query_of(target, key);
    guard has else { return 0; }
    let n, ok = parse_int(v);
    return if ok { n } else { 0 };
}

thread_fn database(box: http::Box) {
    var running = true;
    while running {
        http::mail_wait(box, 1000);
        http::mail_take(box) { key, tag, bytes =>
            if tag == REPORT {
                let jobs, ok = from_bytes<ReportJob[>..]>(bytes);
                if ok && jobs.len == 1 { report(jobs[0]); }
            } else if tag == EXPORT {
                let jobs, ok = from_bytes<ExportJob[>..]>(bytes);
                if ok && jobs.len == 1 { export_rows(jobs[0]); }
            } else {
                running = false;
            }
        };
    }
    http::mail_close(box);
}

fn report(j: ReportJob) {
    var total = 0;
    for d in j.from..j.to + 1 { total += j.org * d; }
    var one: ReportReply[>..] = [];
    one.push(ReportReply { total: total, days: j.to - j.from + 1 });
    http::mail_send(j.reply, LAST, to_bytes(one));
}

fn export_rows(j: ExportJob) {
    var text: u8[>..] = [];
    for i in j.rows { format(text, j.org, ",", i, ",", i * i, "\n"); }
    let whole = http::mail_send(j.reply, LAST, text);
    let n = (text.len + j.piece - 1) / j.piece;
    print("database: ", text.len, " bytes whole: ", if whole == http::FULL { "FULL" } else { "sent" },
          "; in ", n, " pieces of at most ", j.piece);
    var at = 0;
    while at < text.len {
        let end = min(at + j.piece, text.len);
        let tag = if end == text.len { LAST } else { MORE };
        // FULL: the worker's box has no free slot, and it is shared by all of
        // the worker's exchanges. Wait for the worker to take some.
        while http::mail_send(j.reply, tag, text[at..end]) == http::FULL { sleep_ms(1); }
        at = end;
    }
}
