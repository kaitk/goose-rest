# 06: Security headers

Status: todo

A middleware that adds the OWASP baseline to every answer inside it, errors included.
The fields are fixed per scope, so they can be written once into `cx.out.common`-style
bytes rather than per request.

Aegon's `security_headers()`
([its guide](https://udaykhare09.github.io/Aegon/guide/security-headers), read
2026-10-20) is the checklist. Its `defaults()` preset, for HTML applications, sends:

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
'none'`, HSTS, `nosniff`, and `X-Frame-Options: DENY`. Check the cheat sheet's current
list when building it.

Two points Aegon's page doesn't cover:

- HSTS only on TLS connections. RFC 6797 §7.2 says a server must not send it over plain
  HTTP, and browsers ignore it there. Behind a proxy that terminates TLS, an option
  sends it anyway.
- A scope inside another can change or omit a field, so a route that a partner site
  embeds can drop `X-Frame-Options` while the rest keep it.

## Acceptance criteria

- [ ] `rest::security_headers(cx, cfg) { ... }` with the HTML and API presets and the
      options above, errors included
- [ ] HSTS only over TLS unless the option says otherwise, and an inner scope's override
- [ ] A golden test for each preset, and for an override
- [ ] Tier A's instructions per request with the middleware recorded
- [ ] The README's "Default headers" row and `docs/reference.md` updated
