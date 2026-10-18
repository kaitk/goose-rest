// docs/tutorial/11-waiting.md and 16-testing.md: the database lane's jobs,
// called as plain functions on a job, and the routes and their case
// functions, answered without a socket or threads. scripts/test.sh runs it through
// TinyCC:
//
//   goose docs/tutorial/11-waiting/test.goose
import std;
import http from "github.com/kaitk/goose-http@d0e3fd4afebcdb9ce032a8c7ebc13e00fe5bf841";
import rest from "../../../";
import db from "../db/";
import .database;
import .app;

fn expect(got: database::AssignReply, status: i32, code: const u8[:]) {
    if got.status != status || got.code != code {
        print("got:  ", got.status, " ", got.code, "\nwant: ", status, " ", code);
        assert(false);
    }
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
    var c = db::open(0);
    expect(database::assign(c, database::AssignJob { project: 1, task: 3, user: 1, assignee: 2 }), 200, "");
    assert(assignee(c, 3) == 2);
    expect(database::assign(c, database::AssignJob { project: 1, task: 4, user: 3, assignee: 2 }), 403, "not_a_member");
    expect(database::assign(c, database::AssignJob { project: 1, task: 4, user: 1, assignee: 3 }), 409, "assignee_not_a_member");
    assert(assignee(c, 4) == 0);

    // The routes, with a box of the test's own where the lane's would be:
    // nothing takes from it but the test.
    let box, e = http::mail_open(2, 256);
    http::exit_on_error(e);
    var app = App { conn: c, db: http::address(box, 0) };
    fn answer(text: const u8[:], wakes: const rest::Wake[:] = []) -> u8[>..] {
        return rest::serve_one(text, app, St { .. }, wakes) { cx =>
            if rest::resumed(cx) { resume(cx.state.waiting, cx); } else { handle(cx); }
        };
    }

    // A route that doesn't wait is answered whole, and one that waits is
    // answered whole when it fails before its ask.
    expect(body_of(answer(get("/v1/in-place/projects/1"))), "{\"id\":1,\"name\":\"goose\",\"owner\":1}");
    expect(body_of(answer(put("/v1/projects/1/tasks/4/assignee?user=2", ""))),
           "{\"error\":\"invalid_parameter\",\"detail\":\"X-User: required\"}");

    // A route that asks sends its job to the box. No loop brings a reply
    // back, so the answer is the 500 of a block that wrote none; the job is
    // what the test checks, done here by the use case.
    let user1 = "X-User: 1\r\n";
    expect(answer(put("/v1/projects/1/tasks/4/assignee?user=2", user1)),
           "HTTP/1.1 500 Internal Server Error\r\nConnection: close\r\nContent-Length: 0\r\n\r\n");
    let n = http::mail_take(box) { key, tag, bytes =>
        let a, ok = rest::asked<database::AssignJob>(bytes);
        assert(ok && tag == database::ASSIGN);
        expect(database::assign(c, a.job), 200, "");
    };
    assert(n == 1 && assignee(c, 4) == 2);

    // The case functions, given the replies the lane would send. Each
    // route still sends its job, so the test empties the box after them.
    let done = rest::value_bytes(database::AssignReply { .. });
    expect(answer(put("/v1/projects/1/tasks/5/assignee?user=2", user1), [rest::Wake { data: done }]),
           "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: 23\r\n\r\n{\"task\":5,\"assignee\":2}");
    let missing = rest::value_bytes(database::AssignReply { status: 404, code: "task_not_found" });
    expect(body_of(answer(put("/v1/projects/1/tasks/9/assignee?user=2", user1), [rest::Wake { data: missing }])),
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
