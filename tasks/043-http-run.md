# 043: Start the workers with `http::run`

Status: done on Goose master `dcc2747` and goose-http `81bbf9b` (2026-10-19), but for
the README's quick start, which waits for releases of both.

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

- [x] The goose-http pin has `http::run` (`81bbf9b`)
- [x] The tutorial, best practices, examples, and benchmark servers call it; no program
      keeps the spawn and wait loops for its workers; lanes spawn theirs in
      `rest::lane_open` (goose-http's task 048)
- [x] `docs/tutorial/01-running.md` explains the one call where it explains the loops now
- [x] `scripts/test.sh` passes on macOS (2026-10-19)
- [ ] `README.md`'s quick start calls `http::run` once goose-http and goose-rest tags
      have it: until then it imports `v0.3.7` and `v0.1.2`, which build with Goose
      `v2026.2`
