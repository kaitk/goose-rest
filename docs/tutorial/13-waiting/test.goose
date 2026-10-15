// docs/tutorial/13-waiting.md: the service's use cases, called as plain
// functions on a job, without HTTP or threads. scripts/test.sh runs it
// through TinyCC:
//
//   goose docs/tutorial/13-waiting/test.goose
import std;
import http from "github.com/kaitk/goose-http@v0.3.1";
import rest from "../../../";
import db from "../db/";
import .service;

fn expect(got: service::AssignReply, status: i32, code: const u8[:]) {
    if got.status != status || got.code != code {
        print("got:  ", got.status, " ", got.code, "\nwant: ", status, " ", code);
        assert(false);
    }
}

fn assignee(c: db::Conn&, task: i64) -> i64 {
    let ts = db::fetch_all<db::Task>(c, "SELECT * FROM tasks WHERE project = $1 ORDER BY id", [1]);
    return ts[task - 1].assignee;
}

fn main() {
    var c = db::open(0);
    expect(service::assign(c, service::AssignJob { project: 1, task: 3, user: 1, assignee: 2 }), 200, "");
    assert(assignee(c, 3) == 2);
    expect(service::assign(c, service::AssignJob { project: 1, task: 4, user: 3, assignee: 2 }), 403, "not_a_member");
    expect(service::assign(c, service::AssignJob { project: 1, task: 4, user: 1, assignee: 3 }), 409, "assignee_not_a_member");
    assert(assignee(c, 4) == 0);
    print("13-waiting: ok");
}
