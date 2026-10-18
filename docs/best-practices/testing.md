# 8. Testing

An application's tests follow Goose's own convention
([Tests](../decisions.md#tests)), and they're laid out by domain, as the code is. Most
are small programs: each calls one domain's code, with no socket or thread, and prints
what it checks for a golden file to compare. A few run the whole server over HTTP. One
small runner, kept in the application itself, runs both kinds.

The code on this page is from [`testing/`](testing/), a slice of the time-tracking API
with two domains, `projects` and `entries`, and their tests:

```text
testing/
  main.goose              the writer lane, the worker, and main
  app.goose               App, St, Waiting, the job tags, and the routes
  projects/  entries/     the domains
  test/
    run_tests.py          the runner
    expect.goose          what the tests share
    projects/             project_rules.goose, project_routes.goose
    entries/              entry_rules.goose, entry_routes.goose, wrong_state.goose
    record_time/          a scenario: requests.sh
    expected/             a golden file for each test and scenario
```

## 8.1 A test imports the application as a package

A test has a `main` of its own, so it can't import `main.goose`. Instead, it imports
the application's folder as a package, which loads `app.goose` and everything
it imports ([Layout by domain](layout.md#27-the-programs-types-are-in-appgoose)). From
[`testing/test/projects/project_routes.goose`](testing/test/projects/project_routes.goose):

```rust
import std;
import http from "github.com/kaitk/goose-http@d0e3fd4afebcdb9ce032a8c7ebc13e00fe5bf841";
import rest from "../../../../../";
import app from "../../";
import expect from "../";
```

Being a root file, a test declares goose-http and goose-rest itself, at the same
releases as `main.goose`. `expect` is `test/expect.goose`: the helpers every test
shares, in one module rather than a copy in each test.

## 8.2 A folder per domain, a golden file per test

Put each domain's tests in `test/<domain>/`, such as `test/projects/`. Each test prints
what it checks, and the runner compares that with `test/expected/<name>.out`. Name each
test for its domain too, as in `project_rules.goose`, because the golden files all
share one folder.

A golden file shows every answer at once, so a reviewer sees what changed in behavior
without reading the test's code. When one fails, the runner prints the difference and
goes on, so one broken rule doesn't hide the rest.

## 8.3 Rules are tested as plain calls

A rule takes typed input and does no I/O, so a test calls it directly
([Routes and rules](routes-and-rules.md#34-why-the-split-pays)). A rule that needs the
time takes `now`, so the test passes a fixed one and gets the same answers on every
run. From [`testing/test/entries/entry_rules.goose`](testing/test/entries/entry_rules.goose):

```rust
fn main() {
    fn tried(started: i64, stopped: i64) -> entries::Error {
        let e, err = entries::new_entry(entries::CreateInput { project: 1, started: started, stopped: stopped }, 1, NOW);
        return err;
    }
    print("an hour, ended: ", tried(NOW - 7200, NOW - 3600));
    print("ending at now: ", tried(NOW - 3600, NOW));
    print("ending before it starts: ", tried(NOW - 3600, NOW - 7200));
    print("ending in the future: ", tried(NOW - 3600, NOW + 1));
}
```

```text
an hour, ended: Error.None
ending at now: Error.None
ending before it starts: Error.EndsBeforeStart
ending in the future: Error.InFuture
```

This is where each case of the domain's logic is tested, in microseconds, which leaves
a route's test only what the route adds.

## 8.4 Routes are tested through `rest::serve_one`

`rest::serve_one` takes one request's bytes and returns the response's, through the
same code `rest::serve` runs, with no socket or thread
([Testing without sockets](../tutorial/09-testing.md)). The test builds the worker state
as `main.goose`'s worker does, and gives each request to the program's `handle`:

```rust
    var a = App { projects: projects, writer: http::address(box, 0) };
    fn answer(text: const u8[:]) -> u8[>..] {
        let out = rest::serve_one(text, a, St { .. }) { cx => handle(cx); };
        return expect::shown(out);
    }

    print("create: ", answer(expect::request("POST", "/projects", "name=goose")));
    print("create with no name: ", answer(expect::request("POST", "/projects", "other=goose")));
```

```text
create: 201 {"id":1,"name":"goose","archived":false}
create with no name: 400 {"error":"invalid_parameter","detail":"name: required"}
create with an empty name: 422 {"error":"project_name_required"}
archive: 200 {"id":1,"name":"goose","archived":true}
archive again: 409 {"error":"project_already_archived"}
archive another: 404 {"error":"project_not_found"}
```

That covers what the route adds to its rules: the extractors' 400s, the status and code
`check` gives each refusal, and the JSON it writes. A stack or a middleware is tested
the same way: give `serve_one` a request without a token, and the answer is the 401.

## 8.5 A route that asks a lane is given its replies

The test plays the lane. It gives the worker state a box of its own where the lane's
would be, and nothing takes from that box but the test, so no thread runs and nothing
waits. From [`testing/test/entries/entry_routes.goose`](testing/test/entries/entry_routes.goose):

```rust
    // The job the route sends, read as the lane reads it.
    answer(expect::request("POST", "/entries", FORM));
    http::mail_take(box) { key, tag, bytes =>
        let j, ok = rest::asked<entries::CreateJob>(bytes);
        print("the job: ", tag == CREATE_ENTRY, " ", j.job.input.project, " ",
              j.job.input.started, " ", j.job.input.stopped);
    };
```

Each reply the lane could send then goes to `serve_one` as a `rest::Wake`, and the
case function answers it. A `Wake` with `timeout: true` stands for a lane that didn't
reply in time, and two jobs left in the box's two slots leave the next route a full box:

```rust
    let late = entries::CreateReply { err: entries::Error.InFuture };
    print("refused: ", answer(expect::request("POST", "/entries", FORM), [rest::Wake { data: rest::value_bytes(late) }]));
    empty_box();
    print("no reply in time: ", answer(expect::request("POST", "/entries", FORM), [rest::Wake { timeout: true }]));
```

```text
create with no project: 400 {"error":"invalid_parameter","detail":"project: required"}
the job: true 1 1767250800 1767254400
created: 201 {"id":1,"project":1,"started":1767250800,"stopped":1767254400}
refused: 422 {"error":"entry_in_future"}
no reply in time: 504 {"error":"timeout"}
full box: 503 {"error":"unavailable"}
```

The job itself is a plain function, tested like a rule. So a route that waits is
covered without any timing: the job it sends, and its answer to a reply, to none in
time, and to a full box.

## 8.6 What must not compile is a fixture

A test file with a `// error: <message>` line must fail to compile, with that message
among the compiler's errors. It guards a promise the types make: a change that
loosens it fails a test. From
[`testing/test/entries/wrong_state.goose`](testing/test/entries/wrong_state.goose), a
route served with request state that has no `Waiting`:

```rust
// error: struct NoState has no field waiting
// The routes served with request state of another type than St: a route that
// asks a lane keeps its step in the state's Waiting, so the program doesn't
// compile.
```

## 8.7 A test that needs the running server is a scenario

A test that needs a socket, a thread, or more than one domain at once is a scenario: a
folder under `test/` with a `requests.sh`. The runner builds `main.goose`, serves it
on a local port with its lanes, sends each request with curl, and compares the
answers with `test/expected/<scenario>.out`. Name a scenario for what the user does,
since it crosses domains. From
[`testing/test/record_time/requests.sh`](testing/test/record_time/requests.sh):

```text
req GET /health
req POST /projects -d name=goose
req POST /entries -d 'project=1&started=1767250800&stopped=1767254400'
req POST /entries -d 'project=1&started=1767254400&stopped=1767258000'
req POST /entries -d 'project=1&started=1767258000&stopped=1767254400'
req POST /projects/1/archive
```

```text
GET /health 200 ok
POST /projects 201 {"id":1,"name":"goose","archived":false}
POST /entries 201 {"id":1,"project":1,"started":1767250800,"stopped":1767254400}
POST /entries 201 {"id":2,"project":1,"started":1767254400,"stopped":1767258000}
POST /entries 422 {"error":"entry_ends_before_start"}
POST /projects/1/archive 200 {"id":1,"name":"goose","archived":true}
```

A scenario shows that the lane really replies and the pieces fit together, but it's
slow, and when it fails it's hard to say where. Keep scenarios few, and every other test
small and in its domain's folder. What depends on timing, such as a reply after the
route has stopped waiting, is a scenario too ([Testing the application](../tutorial/16-testing.md#the-running-server)).

## 8.8 The application keeps its own runner

Keep a `test/run_tests.py` in the application rather than install a shared one, as
Goose and goose-rest each keep their own.
[`testing/test/run_tests.py`](testing/test/run_tests.py) is about 140 lines of Python to
copy. It finds the tests and scenarios, runs the small
tests through the compiler's TinyCC and the fixtures through `goose --check`, serves
the program for the scenarios, and reports every failure:

```text
$ python3 test/run_tests.py
ok   entries/entry_routes.goose
ok   entries/entry_rules.goose
ok   entries/wrong_state.goose
ok   projects/project_routes.goose
ok   projects/project_rules.goose
ok   record_time
6 passed
```

`--bless` writes each output as its golden file, for a new test or a change in behavior
you mean to make. Review the golden file's diff as you would the code's.

---

[Best practices](README.md) · Previous: [State](state.md)
