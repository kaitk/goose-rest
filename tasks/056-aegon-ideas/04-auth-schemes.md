# 04: Basic, API key, and cookie authentication, and role guards

Status: todo

`rest::bearer` handles one scheme. Aegon's
[auth guide](https://udaykhare09.github.io/Aegon/guide/auth) (read 2026-10-20) has four
extractors, each passing the credential to the program's verifier and storing the
principal it returns for the route:

- Bearer, with a one-line form that takes a JWT verifier (subtask 05)
- A cookie, by name, also with a JWT form
- An API key in a named header
- Basic (RFC 7617), with a realm

Each answers 401 with problem details and the right `WWW-Authenticate` challenge. Each
takes an `on_unauthorized` hook for a custom answer, and an option that lets a request
without credentials through, for optional authentication.

Role guards: `require_role` (one role, or all of several) and `require_any_role`,
answering 403 with the missing role named. Aegon checks at compile time that the
principal has roles. In goose-rest the principal goes in `cx.state`, and a guard is an
inline block around the route that reads a roles field there. It compiles to the same
`if` the best practices show, so it adds no run-time cost.

## Acceptance criteria

- [ ] `rest::basic`, `rest::api_key`, and `rest::cookie_auth`, or names that fit the
      reference, with 401 and the right `WWW-Authenticate` for Basic
- [ ] An optional form for each that runs the block without a credential, and an
      `on_unauthorized` hook
- [ ] `rest::require_role` and `rest::require_any_role` over a principal in `cx.state`,
      with 403 naming the missing role
- [ ] Tests for missing, malformed, and valid credentials, and for each guard
- [ ] The README's middleware table and `docs/reference.md` updated
