# 057: Inline a block called once, whatever its size

Status: cancelled (2026-10-20), by its own step 1: the size limit isn't what keeps
design A's calls, and removing every cause makes the programs slower. No pull request,
and #33 keeps its answer.

A Goose pull request for the second change the maintainer proposed in
[aardappel/goose#33](https://github.com/aardappel/goose/issues/33) (2026-10-13): always
inline a function value called once, or give it a higher limit. Goose then inlines a
function used once only up to `ONCEMAX`, 200 nodes (`src/optimize.h`, `TryInline`),
and the limit stays for named functions. It keeps a program's single-use helpers from
folding into one huge `main`.

At the time, goose-rest answered that `inline fn` on its block-taking functions was
enough. [Spike 12](../../spikes/12-compact-routes/README.md) shows where it isn't: `inline
fn` covers `routes`, `route`, and `attempt`, but not the block a program hands them,
which can't be marked. In design A, that block is a program's whole route table. Past
200 nodes, it stays a call on every request, and the chain around it stays out of line:
+42 to +164 instructions per request on `bench/routes.sh`'s 60 routes (task 056.01).
A block literal has one call site by construction, and blocks that large are rare, so
the case `main` was protected from doesn't come back.

The change is the used-once condition in `TryInline`: a callee that is a function
value's body skips the `ONCEMAX` cap. The cold-branch rule, the `MAXNEST` depth limit,
and every limit for named functions stay as they are. If the maintainer prefers a
higher cap to none, take that.

## Step 1's result (2026-10-20)

A Goose build of `1e31b6d` with `ONCEMAX` at 1,000,000,000 inlines `v1` into `attempt`,
but `routes`, `route`, and `attempt` stay calls in `short60` and `hand60` alike. Today's
form never folded them either: it keeps the same chain for every `/v1` request.
`attempt` stays a function because extractors left as calls return from it
(`rest::param_int` at 33 calls, `rest::param` at 7, and `rest::query_int` and its kin,
which have two results, and which Goose never inlines). `route` and `routes` stay calls
because each hands the next a block that reads its locals. Removing all three causes
compiles both forms to one function, which costs +104 to +172 instructions per request
in `/v1` ([spike 12](../../spikes/12-compact-routes/README.md#which-routes-stay-out-of-line)).

## Steps

1. Confirm the cause before writing the change. Build Goose with `ONCEMAX` raised
   to a large value, and rebuild spike 12's design A (`bench/routes/short60.goose` at
   `0fda9a2`). The C should fold `routes`, `route`, `attempt`, and the scope function
   into `handle`, as today's form does. If the chain stays, the cause is something else:
   stop and report that.
2. Find how `TryInline` can tell a function value's body from a named function
   (`FnSpec::isfunval`, or how a block's specialization is made), and make the change
   there. A comment on `ONCEMAX` says why function values are exempt.
3. Add a Goose test in the style of the repository's inlining tests: a block of more
   than 200 nodes given to an `inline fn` and called once is inlined, and a named
   function of the same size called once still isn't.
4. Run Goose's own test suite, and check that its build time and the size of the C it
   writes for its samples don't grow noticeably. That was the reason for the cap.
5. Measure again: `bench/routes.sh` with `SERVERS="hand60 short60 short60b"` at
   `0fda9a2`, against the local Goose. If A matches today's form within the spread,
   reopen task 056.01 on design A.
6. Open the pull request from the `fork` remote, on a branch from `upstream`'s
   default branch, in a Goose worktree or clone of its own, not `../goose`. Reply on #33
   with the spike's numbers and why `inline fn` didn't cover this case.

## Acceptance criteria

- [ ] Step 1's build shows the cap is the cause, with the C compared
- [ ] The change in `TryInline`, with its test, passes Goose's test suite
- [ ] Goose's build time and the C size of its samples recorded before and after
- [ ] Design A's counts with the change recorded in spike 12's README
- [ ] The pull request open, and #33 answered with a link to it
