// docs/tutorial/11-bodies-in-pieces.md: attachments of any size, written to
// a file a piece at a time as they arrive, never held whole; and a multipart
// form of a note and a file, read the same way. Attachments go in the
// directory ATTACHMENTS names, "attachments" by default. One worker: the
// next attachment's id lives in the worker.
//
//   goose build -o build/attachments docs/tutorial/11-bodies-in-pieces/main.goose
//   build/attachments 8080
//   curl -s --data-binary @photo.jpg localhost:8080/v1/projects/1/attachments
//   curl -s -F note=Plans -F file=@plans.pdf localhost:8080/v1/projects/1/attachments/form
import std;
import os;
import http from "github.com/kaitk/goose-http@v0.3.4";
import rest from "../../../";

// The most bytes of an attachment: project 1's plan takes up to 1 GB, which
// no worker could hold whole, and project 2's up to 64 KB.
let LARGE_LIMIT: i64 = 1 << 30;
let SMALL_LIMIT: i64 = 64 * 1024;

let PROJECTS = 2;

// What each route that reads its body in pieces needs at each call.
enum Waiting {
    None,
    Attachment { project: i64, id: i64 },
    Form { project: i64, id: i64 },
}

// The multipart form's parts this program keeps.
let NO_PART: u8 = 0;
let NOTE: u8 = 1;
let FILE: u8 = 2;

struct St {
    waiting: Waiting = Waiting.None,
    part_path: u8[..256] = [],   // the file being written, with ".part" until it's whole
    size: i64 = 0,
    stored: bool = true,
    form: http::Multipart = http::Multipart { .. },
    part: u8 = NO_PART,
    note: u8[..128] = [],
}

// The worker's state: where attachments go, and the next one's id.
struct App { dir: const u8[:], next: i64 = 1 }

struct Attached { project: i64, id: i64, size: i64, note: const u8[:] = "" }

fn format(out: u8[>..]&, a: const Attached&) {
    format(out, "{\"project\":", a.project, ",\"id\":", a.id, ",\"size\":", a.size);
    if a.note.len > 0 {
        out.append(",\"note\":");
        http::json_string(out, a.note);
    }
    out.push('}');
}

fn handle(cx) {
    rest::routes(cx) { cx =>
        if rest::on(cx, "GET", "/health") {
            rest::text(cx, 200, "ok");
        } else if rest::on(cx, "POST", "/v1/projects/:id/attachments") {
            rest::route(cx) { attach(cx, project(cx)); };
        } else if rest::on(cx, "POST", "/v1/projects/:id/attachments/form") {
            rest::route(cx) { attach_form(cx, project(cx)); };
        } else {
            rest::otherwise(cx);
        }
    };
}

fn project(cx) -> i64 {
    let id = rest::param_int(cx, "id");
    guard id >= 1 && id <= PROJECTS else { rest::fail(cx, 404, "project_not_found"); }
    return id;
}

fn limit_of(project: i64) -> i64 { if project == 1 { LARGE_LIMIT } else { SMALL_LIMIT } }

// POST /v1/projects/:id/attachments: any size up to the project's limit,
// written a piece at a time.
fn attach(cx, project: i64) {
    let id = cx.app.next;
    // Reads nothing yet. A Content-Length over the limit gets 413, which leaves
    // the route here; otherwise the body's pieces come later, to
    // resume(Waiting.Attachment), once this route has returned.
    rest::body_in_pieces(cx, limit_of(project), Waiting.Attachment { project: project, id: id });
    // Accepted: take the id, and name the file the pieces go to.
    cx.app.next++;
    cx.state.part_path = str(cx.app.dir, "/", project, "-", id, ".part");
}

fn resume(w: Waiting.None, cx) { rest::fail(cx, 500, "not_waiting"); }

fn resume(w: Waiting.Attachment, cx) {
    if cx.kind == http::BODY {
        store(cx, cx.body);
        guard cx.state.stored else { rest::fail(cx, 500, "not_stored"); }
    } else if cx.kind == http::END {
        keep(cx, w.project, w.id, "");
    } else if cx.kind == http::CLOSED {
        // The client went, the body passed its limit, or the route failed.
        delete_file(cx.state.part_path);
    }
}

// Appends bytes to the attachment's .part file, and counts them.
fn store(cx, bytes: const u8[:]) {
    if bytes.len > 0 && !append_file(cx.state.part_path, bytes) { cx.state.stored = false; }
    cx.state.size += bytes.len;
}

// Renames the whole attachment from its .part name, and answers 201.
fn keep(cx, project: i64, id: i64, note: const u8[:]) {
    let path = cx.state.part_path[..cx.state.part_path.len - 5];
    // An empty attachment has no .part file yet.
    if cx.state.size == 0 { write_file(cx.state.part_path, ""); }
    guard rename_file(cx.state.part_path, path) else {
        delete_file(cx.state.part_path);
        rest::fail(cx, 500, "not_stored");
    }
    rest::json(cx, 201, Attached { project: project, id: id, size: cx.state.size, note: note });
}

// POST /v1/projects/:id/attachments/form: a multipart form of a note and a
// file, the file written a piece at a time as attach writes one.
fn attach_form(cx, project: i64) {
    // Reads the Content-Type's boundary into the parser kept in the state.
    guard http::start_multipart(cx.req, cx.state.form) else { rest::fail(cx, 415, "unsupported_media_type"); }
    // Then as attach does: the pieces come later, to resume(Waiting.Form).
    let id = cx.app.next;
    rest::body_in_pieces(cx, limit_of(project), Waiting.Form { project: project, id: id });
    cx.app.next++;
    cx.state.part_path = str(cx.app.dir, "/", project, "-", id, ".part");
}

fn resume(w: Waiting.Form, cx) {
    if cx.kind == http::BODY {
        // A piece can end one part and start the next, or stop mid-head:
        // each_part calls the block for what the piece completes, and keeps
        // the rest in cx.state.form for the next piece.
        let ok = http::each_part(cx.state.form, cx.body) { part =>
            match part {
                // A part begins: note it's the note, the file, or another.
                Head h => form_part(cx, h.fields),
                // Some of its content: the file's to disk, the note's to the
                // state, up to 128 bytes.
                Data d => {
                    if cx.state.part == FILE { store(cx, d.bytes); }
                    else if cx.state.part == NOTE { cx.state.note.append(d.bytes[..min(d.bytes.len, 128 - cx.state.note.len)]); }
                },
                End => { cx.state.part = NO_PART; },
            }
        };
        guard ok else { rest::fail(cx, 400, "invalid_multipart"); }
        guard cx.state.stored else { rest::fail(cx, 500, "not_stored"); }
    } else if cx.kind == http::END {
        // The body has all come; a form cut short lacks its closing boundary.
        guard http::multipart_done(cx.state.form) else {
            delete_file(cx.state.part_path);
            rest::fail(cx, 400, "invalid_multipart");
        }
        keep(cx, w.project, w.id, cx.state.note);
    } else if cx.kind == http::CLOSED {
        delete_file(cx.state.part_path);
    }
}

// Which of the form's parts comes next: "note", "file", or another, which
// is read and dropped.
fn form_part(cx, fields: const u8[:]) {
    let name, filename, ok = http::disposition(fields);
    cx.state.part = if !ok { NO_PART } else if name == "note" { NOTE } else if name == "file" { FILE } else { NO_PART };
}

thread_fn worker(cfg: http::Config, dir: u8[..200]) {
    var app = App { dir: dir };
    let e = rest::serve(cfg, app, St { .. }) { cx =>
        if rest::resumed(cx) {
            rest::route(cx) { resume(cx.state.waiting, cx); };
        } else {
            handle(cx);
        }
    };
    if e.code != 0 { http::report(e); }
}

fn main() {
    let a = args();
    var port: i64 = 8080;
    if a.len > 1 {
        let p, ok = parse_int(a[1]);
        if ok { port = p; }
    }
    var dir: u8[>..] = [];
    if !env("ATTACHMENTS", dir) { dir.append("attachments"); }
    guard dir.len <= 200 && make_dir(dir) else {
        write_stderr(str("can't make ", dir, "\n"));
        return;
    }
    var fixed: u8[..200] = [];
    fixed.append(dir);
    http::exit_on_error(http::stop_on_signals());
    // The server's limit goes up to the largest route's.
    let cfg = http::Config { port: port as i32, workers: 1, max_body: LARGE_LIMIT, .. };
    thread_wait(thread_spawn(worker, cfg, fixed));
}
