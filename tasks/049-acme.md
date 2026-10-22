# 049: ACME, a package of its own

Status: in-progress (asked for 2026-10-19).
[goose-acme](https://github.com/kaitk/goose-acme), at `v0.0.2`, gets and renews
certificates from Pebble (2026-10-22). A goose-rest server
waits on goose-http: its `http.tls` must choose a context per connection, and its
`connect` must resolve names for Let's Encrypt (goose-acme's task 001).

A Goose server gets and renews its certificates from Let's Encrypt in the process, so one
binary can face the internet without Caddy or nginx (task 047, "Beyond HttpArena: one
binary"). snowtime-native does this today with rustls-acme: TLS-ALPN-01 on port 443,
Let's Encrypt production or staging, and a cache of account and certificate keys in a
private directory (`crates/host/src/edge/`, and its `README.md`, "ACME").

## Where it lives

ACME is a package of its own, not part of goose-tls or goose-http (2026-10-19):

- goose-tls is the bottom layer. ACME needs HTTPS requests and JSON, so a `tls.acme`
  module would make goose-tls depend on an HTTP client while goose-http's `http.tls`
  depends on goose-tls.
- Other Goose HTTP servers should be able to use it without goose-http.
- It changes with Let's Encrypt's API and policies, and tests against Pebble and Let's
  Encrypt's staging service, on its own schedule.

The package does no network I/O (2026-10-22). Its flow blocks, and calls overloads on
two values the program passes: one carries each HTTPS request, the other serves each
challenge certificate. This replaces the proposal of a state that hands the program
each request: renewal runs every two months, on a lane. goose-acme's module
`acme.socket` carries the requests over goose-http's blocking socket (its task 053).
The package's decisions are in goose-acme's `docs/decisions.md`.

## What it needs

- From goose-tls (its task 003): choosing a certificate per connection from the SNI name
  and the offered ALPN list, so `acme-tls/1` gets the challenge certificate; replacing a
  server certificate while running; an EC P-256 key, ES256 signing for JWS, a CSR, and a
  self-signed certificate with the `acmeIdentifier` extension (RFC 8737). Its errors come
  through `return ... from`.
- Client TLS, for the ACME directory's HTTPS (goose-tls).
- SHA-256 for the key authorization and the JWK thumbprint (RFC 7638), from goose-hash.
- JSON reading and writing; check whether a Goose package already has what it needs.
- Renewal before expiry, and a cache directory created 0700 with files 0600.

Out of scope, as in snowtime-native: wildcard certificates (TLS-ALPN-01 can't issue them)
and the HTTP-01 and DNS-01 challenges.

## Answered

- The name is goose-acme (2026-10-22), on GitHub as `kaitk/goose-acme`.
- The cache keeps rustls-acme's layout as its only format, with no setting
  (2026-10-22): a server moved from snowtime-native keeps its account and certificates,
  and the directory URL in each file's name keeps staging and production apart. A
  goose-acme test reads a cache rustls-acme's way of writing it, and ring reads back
  what goose-acme writes.
- Goose's `os` can't set a file's mode, so a few lines of C in goose-acme make the
  cache 0700 and its files 0600 (2026-10-22), until it can.

## Acceptance criteria

- [x] The package's repository, with the no-I/O design settled in its decisions
      (goose-acme `v0.0.2`, 2026-10-22)
- [x] goose-tls has the hooks above (its task 003, 2026-10-19)
- [ ] A certificate issued by a local Pebble to a goose-rest test server, and renewed
      while it serves, without a restart. goose-acme's `scripts/pebble.sh` does this
      with a Python server answering the challenges; a goose-rest server waits on
      goose-http's `http.tls` choosing a context per connection
- [ ] The same against Let's Encrypt's staging service, which waits on goose-http's
      `connect` resolving names
- [x] The cache's directory and file modes checked by a test (goose-acme's
      `test/cache/modes.goose`)
- [x] Used through no goose-http API but its outbound connections, shown by a test
      driver that carries its requests another way (goose-acme's fake CA in
      `test/fake.goose`)
