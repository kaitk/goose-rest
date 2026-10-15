// A fake database for the tutorial's pages 13 to 15, called the way a
// blocking driver such as Rust's sqlx or postgres is: a connection, a
// statement with bound parameters, and rows read into structs. The rows live
// in memory, and each statement sleeps delay_ms, as a query over a network
// would. It knows only the statements the tutorial runs, and aborts on any
// other, so that a statement changed in a page can't pass unnoticed.
//
//   var c = db::open(20);
//   let p, found = db::fetch_one<db::Project>(c, "SELECT * FROM projects WHERE id = $1", [id]);
namespace db;

import std;
import os;

struct Project { id: i64 = 0, name: u8[..64] = "", owner: i64 = 0 }
struct Member { project: i64 = 0, user: i64 = 0 }
struct Task { id: i64 = 0, project: i64 = 0, title: u8[..64] = "", assignee: i64 = 0 }

struct Tables {
    projects: Project[..16] = [],
    members: Member[..64] = [],
    tasks: Task[..256] = [],
}

// A connection: its tables, and what they were when the transaction began.
struct Conn { delay_ms: i64 = 0, data: Tables = Tables { .. }, saved: Tables = Tables { .. }, in_tx: bool = false }

// A connection to a database of two projects: goose, which users 1 and 2
// are members of, with five tasks, and gander, user 2's, with one.
fn open(delay_ms: i64) -> Conn {
    var c = Conn { delay_ms: delay_ms, .. };
    c.data.projects.push(Project { id: 1, name: "goose", owner: 1 });
    c.data.projects.push(Project { id: 2, name: "gander", owner: 2 });
    c.data.members.push(Member { project: 1, user: 1 });
    c.data.members.push(Member { project: 1, user: 2 });
    c.data.members.push(Member { project: 2, user: 2 });
    for i in 5 { c.data.tasks.push(Task { id: i + 1, project: 1, title: str("Task ", i + 1), assignee: 0 }); }
    c.data.tasks.push(Task { id: 6, project: 2, title: "Name it", assignee: 2 });
    return c;
}

fn begin(c: Conn&) {
    query(c);
    c.saved = c.data;
    c.in_tx = true;
}

fn commit(c: Conn&) {
    query(c);
    c.in_tx = false;
}

fn rollback(c: Conn&) {
    query(c);
    if c.in_tx { c.data = c.saved; }
    c.in_tx = false;
}

// The first row sql selects, and whether there is one.
fn fetch_one<T>(c: Conn&, sql: const u8[:], args: const i64[:]) -> T, bool {
    query(c);
    var v = default<T>();
    let found = row(c, sql, args, v);
    return v, found;
}

// Every row sql selects.
fn fetch_all<T>(c: Conn&, sql: const u8[:], args: const i64[:]) -> T[>..] {
    query(c);
    var out: T[>..] = [];
    rows(c, sql, args, out);
    return out;
}

// Runs an INSERT or UPDATE, and returns the rows it changed.
fn execute(c: Conn&, sql: const u8[:], args: const i64[:]) -> i64 {
    query(c);
    if sql == "UPDATE tasks SET assignee = $1 WHERE id = $2 AND project = $3" {
        var n = 0;
        for &t in c.data.tasks {
            if t.id == args[1] && t.project == args[2] { t.assignee = args[0]; n++; }
        }
        return n;
    }
    if sql == "INSERT INTO members (project, user) VALUES ($1, $2)" {
        c.data.members.push(Member { project: args[0], user: args[1] });
        return 1;
    }
    unknown(sql);
    return 0;
}

fn query(c: Conn&) {
    if c.delay_ms > 0 { sleep_ms(c.delay_ms); }
}

fn unknown(sql: const u8[:]) {
    abort(str("db: a statement this fake doesn't know: ", sql));
}

fn row(c: Conn&, sql: const u8[:], args: const i64[:], v: Project&) -> bool {
    guard sql == "SELECT * FROM projects WHERE id = $1" else { unknown(sql); }
    for p in c.data.projects {
        if p.id == args[0] { v = p; return true; }
    }
    return false;
}

fn row(c: Conn&, sql: const u8[:], args: const i64[:], v: Member&) -> bool {
    guard sql == "SELECT * FROM members WHERE project = $1 AND user = $2" else { unknown(sql); }
    for m in c.data.members {
        if m.project == args[0] && m.user == args[1] { v = m; return true; }
    }
    return false;
}

fn rows(c: Conn&, sql: const u8[:], args: const i64[:], out: Task[>..]&) {
    guard sql == "SELECT * FROM tasks WHERE project = $1 ORDER BY id" else { unknown(sql); }
    for t in c.data.tasks {
        if t.project == args[0] { out.push(t); }
    }
}
