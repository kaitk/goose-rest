# 049: ACME, a package of its own

Status: todo (asked for 2026-10-19). goose-tls's task 001 and its hooks for an outside
ACME package (its task 003) are done (2026-10-19).

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

Proposed: no I/O in the package, as in goose-tls and goose-postgres. Its state hands the
program the HTTP requests to send and takes their responses, and tells the program which
challenge certificate to serve and when a new certificate is ready. It then depends on
goose-tls and goose-hash alone, and any server or HTTP client can carry it. goose-http,
or goose-rest, adds a small driver over goose-http's outbound connections (goose-http's
task 053).

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

## Open

- The package's name and repository (`goose-acme` is the obvious one), created when its
  first code is near.
- Whether it reads rustls-acme's cache directory, so a server moved from snowtime-native
  keeps its certificates. rustls-acme's file format isn't checked yet.

## Acceptance criteria

- [ ] The package's repository, with the no-I/O design settled in its decisions
- [x] goose-tls has the hooks above (its task 003, 2026-10-19)
- [ ] A certificate issued by a local Pebble to a goose-rest test server, and renewed
      while it serves, without a restart
- [ ] The same against Let's Encrypt's staging service
- [ ] The cache's directory and file modes checked by a test
- [ ] Used through no goose-http API but its outbound connections, shown by a test
      driver that carries its requests another way
