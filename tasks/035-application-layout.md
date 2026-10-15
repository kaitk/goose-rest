# 035: One way to lay out an application, as a part of the tutorial

Status: todo (asked for 2026-10-15)

The tutorial's pages teach goose-rest's mechanisms one at a time, and leave how a whole
application is laid out to the reader. A part of its own gives one opinionated way to
do it: the way goose-rest's authors build their own applications, and recommend
following. It isn't required, and says so once, but it doesn't hedge or list
alternatives: one answer to each question a growing application meets, where the other
pages show the options. The value is in a convention everyone follows, so the part
picks one and keeps to it (2026-10-15). Its model is snowtime's
backend, which is grouped by domain: `src/server/<domain>/` holds the domain's routes,
its rules, and its schemas; a route only wires, its handler one call of its rule; and
code starts in its domain and moves out once a second one needs it (snowtime's
`AGENTS.md`).

It rebuilds part two's application in that shape, so the reader sees an application
they know laid out, rather than a new one.

## What the part settles

1. **Layout.** A folder per domain with its routes (wiring only), its rules, and its part
   of the schema; shared code apart; one root file that serves and dispatches.
2. **Routes and rules.** A route extracts, calls one rule, and answers; a rule takes
   typed input and returns a result or a domain error, with no `cx`, so it is tested as
   a plain call.
3. **Middleware and stacks.** A middleware is named for what it does, a verb
   (`authenticate`, `resolve_tenant`, `limit_rate`), and a stack for whose routes it
   serves, a noun for its audience (`public`, `members`, `admin`), with the stacks in
   one file, and no name as generic or keyword-like as `api` (2026-10-15); a block's
   parameter for what it's given (`user`, `tenant`). The user prefers verbs to
   participles such as `authed` (2026-10-15). Task 034 builds stacks; this part names
   them.
4. **State and services.** What goes per worker, on a service thread, and in the shared
   store, by what the data is (task 027).
5. **Errors.** One shape, and each domain's codes in one place.
6. **Naming.** Files, rules, `Waiting` variants, case functions, and stacks.
7. **Testing.** Rules as plain calls, routes with `rest::serve_one` (replies included),
   and a few tests over HTTP.

## Acceptance criteria

- [ ] The tutorial gets a part of its own, after the mechanism pages, that says plainly
      it's one suggested way, with a page per topic above or fewer where they're short
- [ ] Part two's application rebuilt in that layout, as the part's program, its answers
      the same as before and checked by `scripts/test.sh`
- [ ] Each convention given once, with its reason, and linked from the mechanism page
      it builds on (page 7 links its naming, page 8 its state, page 16 its testing)
- [ ] The index lists the part, and the README's tutorial link mentions it
