# 06: Security headers

Status: done

A middleware that adds the OWASP baseline to every answer inside it, errors included.
The fields are fixed per scope, so they can be written once into `cx.out.common`-style
bytes rather than per request.

Aegon's `security_headers()`
([its guide](https://udaykhare09.github.io/Aegon/guide/security-headers)) is the
checklist. Its `defaults()` preset, for HTML applications, sends:

| Field | Default | Options |
|---|---|---|
| `X-Content-Type-Options` | `nosniff` | on, off |
| `X-Frame-Options` | `DENY` | `SAMEORIGIN`, omitted (when CSP `frame-ancestors` does the job) |
| `X-XSS-Protection` | `0` | on, off |
| `Referrer-Policy` | `strict-origin-when-cross-origin` | the eight values of the spec |
| `Strict-Transport-Security` | `max-age=31536000; includeSubDomains` | max age, subdomains, `preload`, off |
| `Cross-Origin-Opener-Policy` | `same-origin` | `same-origin-allow-popups`, `unsafe-none`, omitted |
| `Cross-Origin-Resource-Policy` | `same-origin` | `same-site`, `cross-origin`, omitted |
| `Cross-Origin-Embedder-Policy` | omitted | `require-corp`, `credentialless`, `unsafe-none` |
| `Content-Security-Policy` | omitted | a policy string, or `-Report-Only` instead |
| `Permissions-Policy` | omitted | a policy string |

An option, off by default, also sends no-cache fields (`Cache-Control: no-cache,
no-store, max-age=0, must-revalidate`, `Pragma`, `Expires: 0`). Aegon's page doesn't
list the `api()` preset's values. goose-rest's API preset follows OWASP's REST Security
Cheat Sheet: `Cache-Control: no-store`, `Content-Security-Policy: frame-ancestors
'none'`, HSTS, `nosniff`, and `X-Frame-Options: DENY`, plus
`X-Permitted-Cross-Domain-Policies: none` from the Secure Headers Project.

HSTS is an ordinary field, on in both presets and possible to turn off. There is
no TLS check or proxy option. Prepare separate policies at setup, then select one
where the handler calls the middleware. A route that a partner site embeds can
select a policy without `X-Frame-Options` while the rest keep it. Nesting
`security_headers` isn't supported.

## Acceptance criteria

- [x] `rest::security_headers(cx, cfg) { ... }` with the HTML and API presets and the
      options above, errors included
- [x] HSTS on in both presets and possible to turn off, and a prepared policy
      selected for the request where the middleware is called
- [x] A golden test for each preset, and for selecting a policy by request target
- [x] Tier A's instructions per request with the middleware recorded
- [x] The README's "Default headers" row and `docs/reference.md` updated
- [x] Both presets checked against OWASP's HTTP Headers Cheat Sheet and the
      OWASP Secure Headers Project, as of today's date, with every field
      they recommend and a preset leaves out listed in the task file with
      the reason
- [x] The fields prepared once per scope, so that a request pays only for
      copying them: tier A's instructions per request recorded with and
      without the middleware, and any cost beyond the copy explained

## OWASP comparison (2026-10-20)

Sources read on this date:

- [HTTP Headers Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/HTTP_Headers_Cheat_Sheet.html)
  (H).
- [Secure Headers Project](https://owasp.org/www-project-secure-headers/), its
  [response headers](https://secure-headers-project.owasp.org/response-headers/)
  (S), and its
  [configuration proposal](https://secure-headers-project.owasp.org/best-practices/#configuration-proposal)
  (P).
- [REST Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/REST_Security_Cheat_Sheet.html#security-headers)
  (R).

These sources differ: H uses `strict-origin-when-cross-origin` for referrers and
`same-site` for CORP; P uses `no-referrer` and `same-origin`. P advises against
preload by default, while H's example includes it. The task's explicit HTML
defaults take precedence where noted. HSTS is emitted whenever enabled, without
checking the transport, as the request of 2026-10-20 specifies. Neither preset
silently opts a host into preload.

Aegon's required guide could not be retrieved: both browser retrieval and a
direct HTTPS fetch failed. Its checklist above has not been independently
reverified in this session.

### HTML preset

| Field | OWASP recommendation | Preset value | Reason for difference |
|---|---|---|---|
| `X-Content-Type-Options` | H/P/R: `nosniff` | `nosniff` | Matches. |
| `X-Frame-Options` | H/P/R: deny framing | `DENY` | Matches. |
| `X-XSS-Protection` | H: omit or `0`; S: deprecated | `0` | Task explicitly disables the legacy filter. |
| `Referrer-Policy` | H: `strict-origin-when-cross-origin`; P: `no-referrer` | `strict-origin-when-cross-origin` | Task's explicit default matches H. |
| `Strict-Transport-Security` | H/P: two years, subdomains, HTTPS; H includes preload | `max-age=31536000; includeSubDomains` | Task chooses one year, opt-in preload, and emission as an ordinary field. |
| `Cross-Origin-Opener-Policy` | H/P: `same-origin` | `same-origin` | Matches. |
| `Cross-Origin-Resource-Policy` | H: `same-site`; P: `same-origin` | `same-origin` | Task chooses the narrower origin boundary. |
| `Cross-Origin-Embedder-Policy` | H/P: `require-corp` | Omitted, configurable | Task explicitly omits it by default. |
| `Content-Security-Policy` | H: tune policy; P: restrict sources | Omitted, configurable, including report-only | Task leaves the HTML application's resource policy to configuration. |
| `Permissions-Policy` | H/P: restrict browser features | Omitted, configurable | Task explicitly leaves feature permissions to the application. |
| `X-Permitted-Cross-Domain-Policies` | P: `none` | `none` | No task decision conflicts. |
| `X-DNS-Prefetch-Control` | H/P: `off` for sensitive pages | `off` | Conservative privacy default; no task decision conflicts. |
| `Cache-Control` | H: prevent sensitive caching; P: `no-store, max-age=0` | Omitted; optional no-cache fields above | Task explicitly makes no-cache opt-in for HTML. |
| `Clear-Site-Data` | P: logout only | Omitted | Clearing sessions on every answer would break the application. |
| `Integrity-Policy`, `Reporting-Endpoints` | P: no generic integrity default; S: reporting endpoint when used | Omitted | Application resources and reporting destinations must be configured together. |

### API preset

| Field | OWASP recommendation | Preset value | Reason for difference |
|---|---|---|---|
| `Cache-Control` | R: `no-store`; P: also `max-age=0` | `no-store` | Task follows R; storage is already prohibited. |
| `Content-Security-Policy` | R: `frame-ancestors 'none'`; P: fuller document policy | `frame-ancestors 'none'` | Task chooses R's API policy. |
| `Strict-Transport-Security` | H/P: two years, subdomains, HTTPS; H includes preload | `max-age=31536000; includeSubDomains` | Same ordinary-field default as HTML. |
| `X-Content-Type-Options` | H/P/R: `nosniff` | `nosniff` | Matches. |
| `X-Frame-Options` | H/P/R: deny framing | `DENY` | Matches R's compatibility baseline. |
| `X-Permitted-Cross-Domain-Policies` | P: `none` | `none` | No task decision conflicts. |
| `Referrer-Policy`, `Cross-Origin-Opener-Policy`, `Cross-Origin-Resource-Policy`, `Cross-Origin-Embedder-Policy`, `Permissions-Policy`, `X-DNS-Prefetch-Control` | H/P: document privacy, isolation, and feature policies | Omitted, configurable | They act on documents, and each costs bytes on every answer. |
| `Clear-Site-Data` | P: logout only | Omitted | Every API answer must not erase sessions or browser storage. |
| `Integrity-Policy`, `Reporting-Endpoints` | P: no generic integrity default; S: reporting endpoint when used | Omitted | No script resources or report destination specified by this task. |

Separate golden tests check every field added to the task's original presets,
beside the preset, selection, error, option, deferred-answer, and compression tests.

### Fields written without this middleware

goose-http's default server loop writes `Server: goose` and `Date`, with
`Connection` when HTTP/1.x framing requires it. `http::Config.server: ""` omits
`Server`. Writers add `Content-Type`, `Content-Length`, or `Transfer-Encoding`
as the response needs them. goose-rest's JSON and error responders use
`application/json`; its text responder uses `text/plain; charset=utf-8`.
Middleware such as CORS and `timed` adds fields only when called. Neither package
writes `X-Powered-By`, ASP.NET version fields, or the other product identification
fields in P's removal list. A field added by a program or proxy stays its concern.

## Setup and request path

`security_html()` and `security_api()` return `SecurityHeaders`, the editable
options. `prepare_security_headers` validates them and builds a `SecurityFields`
value's bytes through `security_fields`, once in worker setup. Prepare `site` and
`embed` there, changing or omitting fields in their options as needed. Select one
policy at the middleware call; nesting isn't supported:

```rust
rest::security_headers(cx, if starts_with(cx.req.target, "/embed") { embed } else { site }) {
    // Dispatch routes here.
};
```

`security_headers` takes the prepared value by reference. With no outer common
fields, it points `cx.out.common` at the prepared bytes; `http::start` copies them
once into the response. Otherwise it first copies the outer fields and policy
into scratch. Beyond copying, it checks the event kind and common length, saves
the common view and scratch length, calls its block, checks for an answer, and
restores the common view. It validates and formats no fields per request.

Deferred answers use `keep_fields`' scratch offsets. If the direct path has no
fields retained by inner middleware, it copies the prepared bytes to scratch
first. The runtime copies retained fields to spill and the later response. Later
calls run the block without reapplying the policy. No connection state grows.

## Measurements (2026-10-20)

Tier A adds **199.0 user instructions/request on io_uring** and **192.8 on epoll**
with the API preset. The fields are prepared once per worker. The default server's
existing common fields require an extra scratch copy, so these totals include more
than one copy of the six fields and a branch. The copy and bookkeeping paths are
explained below; neither options nor field text are rebuilt during a request.

### Environment and method

- Machine: `Tiamat`, AMD Ryzen 7 5800X3D, 8 cores, 16 logical CPUs.
- Windows 11 Pro 26H2, build `10.0.26300.9711`; WSL `3.0.3.0`.
- Ubuntu 26.04.1 LTS; kernel `6.18.54.1-microsoft-standard-WSL2`,
  `#1 SMP PREEMPT_DYNAMIC Tue Oct 6 19:13:07 UTC 2026`, x86-64.
- goose-rest source: `f5d2358cd3a38f53ddac50e245c2e21a60355f9f`, based on
  `bd6f0b1355fa2ffd827079bdb04ee7ad9f7204db`. The source was identical during
  measurement and at the commit. The worktree, compiler, build cache, datasets,
  executable, and logs were on the Linux filesystem.
- Goose: pinned commit `f114b5ac52cfad4bc73038aede53ac7e470b0ad3`;
  goose-http: `v0.4.3`, commit `0a016bb079a890b725d92e43715e214f9a6015db`.
- GCC `15.2.0` (`Ubuntu 15.2.0-16ubuntu1`), Goose optimization `-O2`;
  perf `6.18.54.1.g26d1ceb55087`; h2load `nghttp2/1.68.0`.
- One server at a time, one worker pinned to CPU 0. h2load uses CPUs 4–15,
  8 threads, 256 connections, and 16 requests in flight per connection.
  Each run makes exactly 10,000,000 HTTP/1.1 `GET /api/items/1` requests,
  with keep-alive and count.sh's unchanged `Accept` header. JSON is serialized
  (`JSON` unset). Every run passed count.sh's check for 10,000,000 2xx responses.
- Three rounds, each ordered io_uring off/on, then epoll off/on. Every cell starts
  a fresh server; perf attaches after the TCP readiness probe. No separate warmup.
  Only the server process and its threads are counted, with
  `perf stat -x, -e instructions:u,cycles:u -p PID`. These are retired user
  instructions, not cycles or elapsed time used as a substitute.

`sudo -n true` and `perf stat -e instructions:u,cycles:u -- true` succeeded before
the run. goose-http's unmodified `bench/count.sh` runs one binary and request at
a time and honors `LOOP`; goose-rest's `bench/rest.sh count` forces epoll and
visits several tiers and servers, so it was not used.

### Commands and runs

From the Linux worktree root, `gh` below names an isolated checkout at the
goose-http commit above. Its two dataset files were copied unchanged from the
existing REST dataset into `build/security-perf/data/`. The compiler is the
repository pin selected by `scripts/goose.sh`.

```sh
out=$PWD/build/security-perf
gh=$out/goose-http
export REST_DATA=$out/data
export GOOSE_HOME=$out/goose-home
GOOSE=$(scripts/goose.sh)
"$GOOSE" build --cc gcc --standalone -o "$out/rest-security" \
    bench/rest/goose-rest/main.goose
mkdir -p "$gh/build/bench"
ln -sf "$out/rest-security" "$gh/build/bench/restc-security"

for run in 1 2 3; do
    for loop in uring epoll; do
        for security in 0 1; do
            echo "RUN=$run LOOP=$loop SECURITY=$security"
            sudo -n env REST_DATA="$REST_DATA" TIER=a LOOP="$loop" SECURITY="$security" \
                RUNS=1 N=10000000 PORT=29656 TARGET=/api/items/1 STATUS=2 \
                sh "$gh/bench/count.sh" restc-security |
                tee "$out/count-$loop-$security-$run.tsv"
        done
    done
done
```

| Loop | Round | Without middleware | `SECURITY=1` | Difference |
|---|---:|---:|---:|---:|
| io_uring | 1 | 4,280.7 | 4,479.7 | +199.0 |
| io_uring | 2 | 4,280.7 | 4,479.7 | +199.0 |
| io_uring | 3 | 4,280.7 | 4,479.7 | +199.0 |
| epoll | 1 | 4,230.4 | 4,423.2 | +192.8 |
| epoll | 2 | 4,230.4 | 4,423.2 | +192.8 |
| epoll | 3 | 4,230.4 | 4,423.2 | +192.8 |

All columns are user instructions/request, to count.sh's 0.1 precision. The
per-loop means are the same as each run: **+4.65% on io_uring**, **+4.56% on epoll**.
The 0.1 precision hides any smaller spread; identical printed values do not imply
an exact zero spread.

Binary SHA-256: `a0c8120617bac4b10ff1c01f9bedffa34d8ed73bf6aa9fa5b43c4018af175d9d`.
Dataset SHA-256 values:

- `arena-items.json`: `0b1307c478cd468356553347fd9e937ca6b5e380b21123102e3aadfe9560f080`.
- `arena-users.json`: `1c8b01193dbee7086bb9481d1ff05d4e3ef0e951ba3be09891c9bfafe92d1182`.

The per-run TSVs, response checks, binary and data hashes, generated C, disassembly,
and profiling output remain under `build/security-perf/` in the measurement worktree.

### Where the difference goes

The six API fields take **235 bytes**, including each field's `: ` and CRLF:

| Field | Bytes |
|---|---:|
| `X-Content-Type-Options: nosniff` | 33 |
| `X-Frame-Options: DENY` | 23 |
| `Strict-Transport-Security: max-age=31536000; includeSubDomains` | 64 |
| `Content-Security-Policy: frame-ancestors 'none'` | 49 |
| `X-Permitted-Cross-Domain-Policies: none` | 41 |
| `Cache-Control: no-store` | 25 |

The default loop passes `Server: goose` and `Date` in `out.common`: **52 bytes**
including CRLF. Therefore `common.len == 0` is false on the measured request.
The request takes `security_headers`' concatenation path:

1. Copy the existing 52 bytes into scratch.
2. Copy the prepared 235 bytes after them, and point `out.common` at that 287-byte view.
3. `http::start` / `status_fields` copies all 287 bytes into the response, where the
   baseline copied 52. The policy is copied twice. The incremental logical copy
   volume is **52 + 235 + (287 - 52) = 522 bytes/request**.

The pinned runtime's `gs_memcpy` copies sizes 17–256 in a loop of 16-byte chunks,
then an overlapping final chunk. The optimized executable uses 14 iterations
of five instructions for the 235-byte copy, plus dispatch and tail: 81 instructions
inside the helper, excluding the call site. Its 52-byte copy takes 26 instructions.
The 287-byte response copy crosses the helper's 256-byte cutoff and dispatches to
libc's `memcpy`, rather than taking the baseline's small-copy loop. Thus one
235-byte copy and a branch is too small a model for this server.

Beyond the byte copies, the generated request callback sets up and advances scratch
metadata, constructs the combined view, saves and restores the common view, and
checks whether the handler answered. A completed tier A GET skips `keep_fields`
and the deferred-answer copies. The worker startup branch selects a dedicated
security serve loop; `SECURITY` itself is not tested on each request. Field validation,
option selection, HSTS formatting, and the other field formatting occur only before
the worker enters that loop.

To check this attribution, a separate epoll profile used the same binary, CPU
placement, request, and 10,000,000-request load for each setting:

```sh
REST_DATA="$out/data" TIER=a LOOP=epoll SECURITY="$security" WORKERS=1 \
    taskset -c 0 "$out/rest-security" 29656 > "$out/profile-$security-server.log" 2>&1 &
pid=$!
until nc -z 127.0.0.1 29656 2>/dev/null; do kill -0 "$pid"; sleep 0.1; done
perf record -e instructions:u -c 100003 -o "$out/profile-$security.data" -p "$pid" -- \
    taskset -c 4-15 h2load --h1 -n 10000000 -c 256 -m 16 -t 8 \
    -H 'Connection: keep-alive' \
    -H 'Accept: text/plain,text/html;q=0.9,application/xhtml+xml;q=0.9,application/xml;q=0.8,*/*;q=0.7' \
    http://127.0.0.1:29656/api/items/1 > "$out/profile-$security-h2load.txt" 2>&1
kill "$pid"
wait "$pid" || true
perf report --stdio -i "$out/profile-$security.data" --no-children \
    --show-total-period --sort dso,symbol --percent-limit 0 -t ';'
objdump -d --disassemble=gs_memcpy "$out/rest-security"
objdump -d --disassemble=http_answer_g4_3994 "$out/rest-security"
objdump -d --disassemble=http_answer_g4_4342 "$out/rest-security"
```

This was run for `security=0` and `security=1`. Both profiles lost zero samples.
WSL perf reported addresses, resolved against `nm -n -S` and the disassembly.
The enabled callback (`http_answer_g4_3994`) contains the two extra scratch-copy
calls; the baseline (`http_answer_g4_4342`) does not. Samples also enter libc's
copy routine with the middleware. Instruction sampling can skid, so the profiles
identify paths rather than assign an exact instruction subtotal to each function.
The table above uses the independent `perf stat` counts, not sampled estimates.

Both criteria are checked: preparation is outside the request loop, and the measured
cost beyond a single copy is accounted for by concatenation, the larger response
copy's dispatch, and scope bookkeeping. This does **not** establish a single-copy
request path for the default server. No middleware or HTTP-loop changes were made
to obtain these measurements.

## Validation (2026-10-20)

`scripts/test.sh` passed in full on macOS with the pinned Goose commit
`f114b5ac52cfad4bc73038aede53ac7e470b0ad3`, goose-http `v0.4.3`, and TypeScript
7.0.2. The run used a writable `GOOSE_HOME` under `build/` and the cached
TypeScript compiler. It passed 91 tests at both `-O0` and `-O2`, including 15 new
security-header tests, and 8 compile-error fixtures. Generator comparisons,
TypeScript checks, HTTP examples, documentation tests and excerpts, spikes, and
the inlining checks passed too. The runner discovers the new tests by their
`main` functions and checks the golden files under `test/expected/`.

The Linux benchmark server built with the pinned Goose compiler and GCC. Before
counting, HTTP checks on both loops verified all six fields on a successful item
GET and a 404, and their absence with `SECURITY=0`. Other response fields matched
after removing `Date`, item JSON matched after removing `servedAt`, and error bodies
matched byte for byte. `git diff --check` passed. The full test suite was not rerun
for this benchmark-only change.
