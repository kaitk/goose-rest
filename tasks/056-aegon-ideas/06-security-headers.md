# 06: Security headers

Status: in-progress; implementation passes, Linux instruction counts pending

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
- [ ] Tier A's instructions per request with the middleware recorded
- [x] The README's "Default headers" row and `docs/reference.md` updated
- [x] Both presets checked against OWASP's HTTP Headers Cheat Sheet and the
      OWASP Secure Headers Project, as of today's date, with every field
      they recommend and a preset leaves out listed in the task file with
      the reason
- [ ] The fields prepared once per scope, so that a request pays only for
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

The current host is macOS (`uname -s`: `Darwin`) and has no `perf` command. Neither
tier A measurement has been made, and both instruction criteria remain unticked.

## Validation (2026-10-20)

`scripts/test.sh` passed in full on macOS with the pinned Goose commit
`f114b5ac52cfad4bc73038aede53ac7e470b0ad3`, goose-http `v0.4.3`, and TypeScript
7.0.2. The run used a writable `GOOSE_HOME` under `build/` and the cached
TypeScript compiler. It passed 91 tests at both `-O0` and `-O2`, including 15 new
security-header tests, and 8 compile-error fixtures. Generator comparisons,
TypeScript checks, HTTP examples, documentation tests and excerpts, spikes, and
the inlining checks passed too. The runner discovers the new tests by their
`main` functions and checks the golden files under `test/expected/`.
