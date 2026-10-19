// The database lane: a run case function per job, which does the job start
// to end on the lane's thread, with plain blocking calls, and the thread
// that owns the connection. test.goose plays them without HTTP.
import std;
import http;
import rest;
import db;
import .app;

fn run(u: DbJob.Project, c: db::Conn&, a) {
    let p, found = db::fetch_one<db::Project>(c, "SELECT * FROM projects WHERE id = $1", [u.id]);
    guard found else { rest::fail(a, 404, "project_not_found"); }
    rest::reply_value(a, p);
}

// Assigns a task, for a user who is a member of its project, to another
// member: four statements in one transaction.
fn run(u: DbJob.Assign, c: db::Conn&, a) {
    db::begin(c);

    // The project exists.
    let p, found = db::fetch_one<db::Project>(c, "SELECT * FROM projects WHERE id = $1", [u.project]);
    guard found else { db::rollback(c); rest::fail(a, 404, "project_not_found"); }

    // The user asking is one of its members, and so is the assignee.
    let m, member = db::fetch_one<db::Member>(c, "SELECT * FROM members WHERE project = $1 AND user = $2", [u.project, u.user]);
    guard member else { db::rollback(c); rest::fail(a, 403, "not_a_member"); }
    let n, assignable = db::fetch_one<db::Member>(c, "SELECT * FROM members WHERE project = $1 AND user = $2", [u.project, u.assignee]);
    guard assignable else { db::rollback(c); rest::fail(a, 409, "assignee_not_a_member"); }

    // The task is in the project: the update changes one row, or none.
    let rows = db::execute(c, "UPDATE tasks SET assignee = $1 WHERE id = $2 AND project = $3", [u.assignee, u.task, u.project]);
    guard rows == 1 else { db::rollback(c); rest::fail(a, 404, "task_not_found"); }

    db::commit(c);
    rest::reply_value(a, Assigned { task: u.task, assignee: u.assignee });
}

// The lane's thread: it owns the connection, and takes jobs from its box one
// at a time, until main stops the lane and every job queued before is done.
thread_fn database(box: http::Box, delay_ms: i64) {
    var c = db::open(delay_ms);
    rest::lane<DbJob>(box) { u, a => run(u, c, a); };
}
