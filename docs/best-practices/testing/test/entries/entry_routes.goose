// The entries' route, which asks the writer lane: the job it sends, and its
// answer to each reply the lane could give, through rest::serve_one. The test
// plays the lane: no thread runs, and nothing waits.
import std;
import http from "github.com/kaitk/goose-http@81bbf9baa315ad3607cd2a3a67fa7d14d154726c";
import rest from "../../../../../";
import app from "../../";
import expect from "../";

let FORM = "project=1&started=1767250800&stopped=1767254400";

fn main() {
    // A box of the test's own, where the writer's would be: two slots.
    let box, e = http::mail_open(2, 256);
    http::exit_on_error(e);
    var projects: projects::Project[>..] = [];
    var a = App { projects: projects, writer: http::address(box, 0) };
    fn answer(text: const u8[:], wakes: const rest::Wake[:] = []) -> u8[>..] {
        let out = rest::serve_one(text, a, St { .. }, wakes) { cx =>
            if rest::resumed(cx) { resume(cx.state.waiting, cx); } else { handle(cx); }
        };
        return expect::shown(out);
    }
    fn empty_box() -> i64 { return http::mail_take(box) { key, tag, bytes => }; }

    // Before the ask: the route's own checks answer at once.
    print("create with no project: ", answer(expect::request("POST", "/entries", "started=1&stopped=2")));

    // The job the route sends, read as the lane reads it.
    answer(expect::request("POST", "/entries", FORM));
    http::mail_take(box) { key, tag, bytes =>
        let j, ok = rest::asked<entries::CreateJob>(bytes);
        print("the job: ", tag == CREATE_ENTRY, " ", j.job.input.project, " ",
              j.job.input.started, " ", j.job.input.stopped);
    };

    // The answer to each reply the lane could send, and to none in time.
    let made = entries::CreateReply { entry: entries::Entry { id: 1, project: 1, started: 1767250800, stopped: 1767254400 } };
    print("created: ", answer(expect::request("POST", "/entries", FORM), [rest::Wake { data: rest::value_bytes(made) }]));
    let late = entries::CreateReply { err: entries::Error.InFuture };
    print("refused: ", answer(expect::request("POST", "/entries", FORM), [rest::Wake { data: rest::value_bytes(late) }]));
    empty_box();
    print("no reply in time: ", answer(expect::request("POST", "/entries", FORM), [rest::Wake { timeout: true }]));
    empty_box();

    // Two jobs fill the box's two slots, and the next route finds it full.
    answer(expect::request("POST", "/entries", FORM));
    answer(expect::request("POST", "/entries", FORM));
    print("full box: ", answer(expect::request("POST", "/entries", FORM)));
}
