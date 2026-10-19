// The database lane: the jobs routes send it, the replies it answers, and a
// function per job that does it start to end on the lane's thread, with plain
// blocking calls. test.goose calls them without HTTP.
namespace database;

import std;
import http;
import rest;
import db;

// A job's tag.
let PROJECT: i32 = 1;
let ASSIGN: i32 = 2;

struct ProjectJob { id: i64 }
struct ProjectReply { status: i32 = 200, code: u8[..32] = "", project: db::Project = db::Project { .. } }

struct AssignJob { project: i64, task: i64, user: i64, assignee: i64 }
struct AssignReply { status: i32 = 200, code: u8[..32] = "" }

fn project(c: db::Conn&, j: ProjectJob) -> ProjectReply {
    let p, found = db::fetch_one<db::Project>(c, "SELECT * FROM projects WHERE id = $1", [j.id]);
    guard found else { return ProjectReply { status: 404, code: "project_not_found" }; }
    return ProjectReply { project: p };
}

// Assigns a task, for a user who is a member of its project, to another
// member: four statements in one transaction.
fn assign(c: db::Conn&, j: AssignJob) -> AssignReply {
    db::begin(c);

    // The project exists.
    let p, found = db::fetch_one<db::Project>(c, "SELECT * FROM projects WHERE id = $1", [j.project]);
    guard found else { db::rollback(c); return AssignReply { status: 404, code: "project_not_found" }; }

    // The user asking is one of its members, and so is the assignee.
    let m, member = db::fetch_one<db::Member>(c, "SELECT * FROM members WHERE project = $1 AND user = $2", [j.project, j.user]);
    guard member else { db::rollback(c); return AssignReply { status: 403, code: "not_a_member" }; }
    let a, assignable = db::fetch_one<db::Member>(c, "SELECT * FROM members WHERE project = $1 AND user = $2", [j.project, j.assignee]);
    guard assignable else { db::rollback(c); return AssignReply { status: 409, code: "assignee_not_a_member" }; }

    // The task is in the project: the update changes one row, or none.
    let n = db::execute(c, "UPDATE tasks SET assignee = $1 WHERE id = $2 AND project = $3", [j.assignee, j.task, j.project]);
    guard n == 1 else { db::rollback(c); return AssignReply { status: 404, code: "task_not_found" }; }

    db::commit(c);
    return AssignReply { .. };
}

// The lane's thread: it owns the connection, and takes jobs from its box one
// at a time, until main stops the lane and every job queued before is done.
thread_fn run(box: http::Box, delay_ms: i64) {
    var c = db::open(delay_ms);
    http::lane(box) { tag, bytes =>
        if tag == PROJECT {
            let a, ok = rest::asked<ProjectJob>(bytes);
            if ok { rest::reply_value(a, project(c, a.job)); }
        } else if tag == ASSIGN {
            let a, ok = rest::asked<AssignJob>(bytes);
            if ok { rest::reply_value(a, assign(c, a.job)); }
        }
    };
}
