# 043: Start the workers with `http::run`

Status: todo. Waits on goose-http's task 048, which waits on
[aardappel/goose#37](https://github.com/aardappel/goose/pull/37) in the Goose pin.

Every goose-rest program ends `main` with the same two loops, because `thread_spawn`
can't name a `thread_fn` passed to a generic function in another module:

    thread_fn worker(cfg: http::Config) {
        let e = rest::serve(cfg) { cx => handle(cx) };
        …
    }
    fn main() {
        …
        for i in http::worker_count(cfg) { ids.push(thread_spawn(worker, cfg)); }
        for id in ids { thread_wait(id); }
    }

Once goose-http has `http::run(cfg, worker)`, the loops become one call. The `thread_fn`
stays: it's where a program calls `rest::serve` with its handler and state.

## Acceptance criteria

- [ ] The goose-http pin has `http::run`
- [ ] The tutorial, best practices, examples, and benchmark servers call it; no program
      keeps the spawn and wait loops for its workers (lanes keep theirs: task 044)
- [ ] `docs/tutorial/01-running.md` explains the one call where it explains the loops now
- [ ] `scripts/test.sh` passes
