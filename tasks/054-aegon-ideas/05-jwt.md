# 05: JWT signing and verification

Status: todo. Task 035's full example and task 047's HttpArena profiles wait on it.

Aegon's [JWT guide](https://udaykhare09.github.io/Aegon/guide/jwt) (read 2026-10-20)
makes a checklist.

Verification:

- The algorithm is pinned by the verifier, never taken from the token's header.
- HMAC is compared in constant time.
- `exp` and `nbf` are checked with a leeway, and `iss` and `aud` when configured.
- A denylist by `jti`, behind an interface a program backs with the store of subtask 09
  or Redis.
- A typed claims struct is the result, and each failure has its own error: malformed,
  algorithm mismatch, signature mismatch, expired, not yet valid, issuer, audience,
  parse error, revoked, key not found.

Signing:

- `iat`, `exp` from a TTL, `nbf`, and a random `jti` are filled in unless the claims
  set them.
- `kid` goes in the header.

Keys:

- A JWKS (RFC 7517) can be served at `/.well-known/jwks.json` or consumed.
- A token without `kid` is refused when the set holds more than one key, and checked
  against the one key otherwise.
- A key resolver looks up a key by `kid`, for rotation.

Decoding without verification, for logging or behind a gateway that verified the token
already.

HS256, HS384, and HS512 can be Goose with goose-hash's HMAC. RS, PS, and ES need goose-tls
and OpenSSL, so they go in an optional module, as compression does. Converting ECDSA
signatures between DER and raw `R || S` (RFC 7515 §3.4) is part of that module.

## Acceptance criteria

- [ ] HS256 signing and verification in Goose, feeding `rest::bearer`'s verifier and
      subtask 04's cookie form
- [ ] Each check above tested, with RFC 7515's and RFC 7519's examples among the vectors
- [ ] JWKS serving and consuming, with the `kid` rule, tested
- [ ] A plan for RS256 and ES256 recorded, with the module and its dependency
- [ ] The README's JWT row and `docs/reference.md` updated
