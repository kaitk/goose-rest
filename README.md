# goose-rest

A minimal REST framework for [Goose](https://github.com/aardappel/goose), on
[goose-http](https://github.com/kaitk/goose-http). Proof of concept; the name is
provisional. The design is in [`docs/plan.md`](docs/plan.md), and the Goose gaps the
spikes found are in [`docs/goose-findings.md`](docs/goose-findings.md).

`spikes/` holds small programs that check the language assumptions the design relies
on. Each spike's README records what it checks, the Goose commit it ran on, and the
result. Rerun them when the Goose pin moves.
