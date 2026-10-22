# Moving the pins

## The Goose pin

The pin is an official Goose release, which builds the same on every platform. At the
start of a session, check for a newer one:

```sh
gh release list -R aardappel/goose --limit 3
```

To move to a new release, update `goose_release` and the four archives' SHA-256 sums in
`scripts/goose.sh`, as goose-http does in the same file. GitHub lists each asset's
digest:

```sh
gh api repos/aardappel/goose/releases/tags/<tag> -q '.assets[] | "\(.name) \(.digest)"'
```

Then run `scripts/test.sh`, which reruns every spike against its recorded output, update
the commit and verdict in each spike's README, and update the release in
`docs/development.md` ("Get Goose") and `README.md`'s quick start, in its own commit.

Pin a commit only when a Goose fix that this repository needs isn't in a release yet,
and return to a release once one has it (2026-10-15). Set `goose_commit` in
`scripts/goose.sh` to the full hash, which every script then builds, and empty it to
return to the release; record the commit and the reason in `docs/development.md`, "Get
Goose". Goose releases often, so work that needs a merged fix lands on `main` on a
pinned commit rather than wait for the release (2026-10-19).

## The goose-http pin

The import in `rest.goose` is the pin: a release tag, or a full commit hash for a fix
not yet released, since git can't fetch an abbreviated one. The same reference is in
each of the package's files, in each root file under `test/`, `examples/`,
`docs/tutorial/`, `docs/best-practices/`, `spikes/`, and `bench/`.
`scripts/move-http-pin.sh` changes every one. `README.md`'s quick start and
`docs/tutorial/01-running.md` name the latest release pair instead, goose-http at the
tag that goose-rest's release imports, and move with a release (2026-10-19):

```sh
scripts/move-http-pin.sh v0.3.1
```

Move it in its own commit once `scripts/test.sh` passes, and update the goose-http
reference each spike's README names. A root that declares goose-http at another commit
than `rest.goose` gets a warning, and from another source an error, so a test can't
point at a local goose-http checkout instead.

## The goose-compress pin

`compression.goose`, the programs that import it, and `docs/reference.md` declare
goose-compress at the tag the pinned goose-http's `compression.goose` names. When the
new goose-http names another, change it in the same commit (2026-10-15).

The same holds for goose-hash, which `websocket.goose` declares at the tag goose-http's
`websocket.goose` names, and goose-tls, which `tls.goose` declares at the tag its
`tls.goose` names, with the programs that import them (2026-10-22).
