// The entries' route, which asks the writer lane: the job it sends, and its
// answer to each reply the lane could give, through plod::serve_one. The test
// plays the lane with its own run case function: no thread runs, and
// nothing waits.
import std;
import http from "github.com/kaitk/goose-http@v0.5.8";
import plod from "../../../../../";
import app from "../../";
import expect from "../";

let FORM = "project=1&started=1767250800&stopped=1767254400";

fn main() {
    // A lane of one box of the test's own, of two slots, and no thread.
    let box, e = http::mail_open(2, 256);
    http::exit_on_error(e);
    var projects: projects::Project[>..] = [];
    var a = App { projects: projects, writer: plod::lane_of<Writes>(box, Use.Write) };
    fn answer(text: const u8[:], wakes: const plod::Wake[:] = []) -> u8[>..] {
        let out = plod::serve_one(text, a, St { .. }, wakes) { cx =>
            if plod::resumed(cx) { plod::on_reply(cx) { resume(cx.state.use, cx); }; } else { handle(cx); }
        };
        return expect::shown(out);
    }
    fn empty_box() -> i64 { return http::mail_take(box) { key, tag, bytes => }; }

    // Before the ask: the route's own checks answer at once.
    print("create with no project: ", answer(expect::request("POST", "/entries", "started=1&stopped=2")));

    // The job the route sends, read as the lane reads it.
    answer(expect::request("POST", "/entries", FORM));
    http::mail_take(box) { key, tag, bytes =>
        plod::lane_job(plod::Jobs<Writes> { .. }, bytes) { u, a => print("the job: ", u); };
    };

    // The answer to each reply the writer's run gives, played on a writer of
    // the test's own, and to none in time.
    var all: entries::Entry[>..] = [];
    var w = Writer { entries: all };
    let input = entries::CreateInput { project: 1, started: 1767250800, stopped: 1767254400 };
    let made = plod::play(a.writer, Writes.EntryCreate { input: input }) { u, a => run(u, w, a); };
    print("created: ", answer(expect::request("POST", "/entries", FORM), [plod::wake(made)]));
    let future = entries::CreateInput { project: 1, started: 1767250800, stopped: 4102444800 };
    let late = plod::play(a.writer, Writes.EntryCreate { input: future }) { u, a => run(u, w, a); };
    print("refused: ", answer(expect::request("POST", "/entries", FORM), [plod::wake(late)]));
    empty_box();
    print("no reply in time: ", answer(expect::request("POST", "/entries", FORM), [plod::Wake { timeout: true }]));
    empty_box();

    // Two jobs fill the box's two slots, and the next route finds it full.
    answer(expect::request("POST", "/entries", FORM));
    answer(expect::request("POST", "/entries", FORM));
    print("full box: ", answer(expect::request("POST", "/entries", FORM)));
}
