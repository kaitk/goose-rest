// docs/tutorial/11-waiting.md and 16-testing.md: the database lane's jobs,
// played without a thread, and the routes and their resume case functions,
// answered without a socket or threads. scripts/test.sh runs it through
// TinyCC:
//
//   goose docs/tutorial/11-waiting/test.goose
import std;
import http from "github.com/kaitk/goose-http@v0.5.0";
import rest from "../../../";
import db from "../db/";
import .database;
import .app;

// What the lane replied: "answered", or the refusal's status and code.
fn expect(p: rest::Played, want: const u8[:]) {
    let status, code = rest::refusal(p);
    let got = if status == 0 { str("answered") } else { str(status, " ", code) };
    if got != want { print("got:  ", got, "\nwant: ", want); assert(false); }
}

fn expect(got: const u8[:], want: const u8[:]) {
    if got != want { print("got:  ", got, "\nwant: ", want); assert(false); }
}

fn assignee(c: db::Conn&, task: i64) -> i64 {
    let ts = db::fetch_all<db::Task>(c, "SELECT * FROM tasks WHERE project = $1 ORDER BY id", [1]);
    return ts[task - 1].assignee;
}

fn body_of(out: const u8[:]) -> const u8[:] { out[find(out, "\r\n\r\n") + 4..] }

fn get(target: const u8[:]) -> u8[>..] { str("GET ", target, " HTTP/1.1\r\n\r\n") }

fn put(target: const u8[:], fields: const u8[:]) -> u8[>..] {
    str("PUT ", target, " HTTP/1.1\r\n", fields, "\r\n")
}

fn main() {
    // A lane of one box of the test's own and no thread: nothing takes from
    // it but the test.
    let box, e = http::mail_open(2, 256);
    http::exit_on_error(e);
    var c = db::open(0);
    var app = App { conn: c, db: rest::lane_of<DbJob>(box, Use.Db) };

    // The use cases, played as the lane runs them, on the test's connection.
    expect(rest::play(app.db, DbJob.Assign { project: 1, task: 3, user: 1, assignee: 2 }) { u, a => run(u, c, a); },
           "answered");
    assert(assignee(c, 3) == 2);
    expect(rest::play(app.db, DbJob.Assign { project: 1, task: 4, user: 3, assignee: 2 }) { u, a => run(u, c, a); },
           "403 not_a_member");
    expect(rest::play(app.db, DbJob.Assign { project: 1, task: 4, user: 1, assignee: 3 }) { u, a => run(u, c, a); },
           "409 assignee_not_a_member");
    assert(assignee(c, 4) == 0);

    // The routes, through the block main.goose's worker gives rest::serve.
    fn answer(text: const u8[:], wakes: const rest::Wake[:] = []) -> u8[>..] {
        return rest::serve_one(text, app, St { .. }, wakes) { cx =>
            if rest::resumed(cx) { rest::on_reply(cx) { resume(cx.state.use, cx); }; } else { handle(cx); }
        };
    }

    // A route that doesn't wait is answered whole, and one that waits is
    // answered whole when it fails before its ask.
    expect(body_of(answer(get("/v1/in-place/projects/1"))), "{\"id\":1,\"name\":\"goose\",\"owner\":1}");
    expect(body_of(answer(put("/v1/projects/1/tasks/4/assignee?user=2", ""))),
           "{\"error\":\"invalid_parameter\",\"detail\":\"X-User: required\"}");

    // A route that asks sends its job to the box. No loop brings a reply
    // back, so the answer is the 500 of a block that wrote none; the job is
    // what the test checks, run here by the lane's own case function.
    let user1 = "X-User: 1\r\n";
    expect(answer(put("/v1/projects/1/tasks/4/assignee?user=2", user1)),
           "HTTP/1.1 500 Internal Server Error\r\nConnection: close\r\nContent-Length: 0\r\n\r\n");
    let n = http::mail_take(box) { key, tag, bytes =>
        rest::lane_job(rest::Jobs<DbJob> { .. }, bytes) { u, a => run(u, c, a); };
    };
    assert(n == 1 && assignee(c, 4) == 2);

    // The resume case functions, given the replies the lane would send:
    // played by a block of the test's own, which needs no database. Each
    // route still sends its job, so the test empties the box after them.
    let done = rest::play(app.db, DbJob.Assign { project: 1, task: 5, user: 1, assignee: 2 }) { u, a =>
        rest::reply_value(a, Assigned { task: 5, assignee: 2 });
    };
    expect(answer(put("/v1/projects/1/tasks/5/assignee?user=2", user1), [rest::wake(done)]),
           "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: 23\r\n\r\n{\"task\":5,\"assignee\":2}");
    let missing = rest::play(app.db, DbJob.Assign { project: 1, task: 9, user: 1, assignee: 2 }) { u, a =>
        rest::fail(a, 404, "task_not_found");
    };
    expect(body_of(answer(put("/v1/projects/1/tasks/9/assignee?user=2", user1), [rest::wake(missing)])),
           "{\"error\":\"task_not_found\"}");
    assert(http::mail_take(box) { key, tag, bytes => } == 2);
    expect(body_of(answer(put("/v1/projects/1/tasks/5/assignee?user=2", user1), [rest::Wake { timeout: true }])),
           "{\"error\":\"timeout\"}");
    assert(http::mail_take(box) { key, tag, bytes => } == 1);

    // Two jobs fill the box's two slots, and the next route finds it full.
    answer(put("/v1/projects/1/tasks/5/assignee?user=2", user1));
    answer(put("/v1/projects/1/tasks/5/assignee?user=2", user1));
    expect(body_of(answer(put("/v1/projects/1/tasks/5/assignee?user=2", user1))), "{\"error\":\"unavailable\"}");
    print("11-waiting: ok");
}
