# 02: Every violation in one answer

Status: todo

A generated reader stops at the first error and answers 400 `invalid_body` with
`detail` and `at`. Aegon collects every violation and answers 422 with a map from JSON
path (`shipping_address.zip`, `items[1].quantity`) to message. A client that builds a
form from the schema can then mark every field at once.

To settle: whether the status moves to 422 or stays 400, and a cap on the number of
violations, so that a hostile body can't make the answer large.

## Acceptance criteria

- [ ] Generated readers collect violations up to a cap, with each one's JSON pointer
- [ ] The answer's shape and status recorded in `docs/decisions.md` and `docs/reference.md`
- [ ] Golden tests for nested objects, arrays, and the cap
- [ ] Tier R's rate with a valid body unchanged
