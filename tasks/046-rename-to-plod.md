# 046: Rename to Plod

Status: in-progress. The package, its namespace, the generator, and the docs are Plod on
branch `plod` (2026-10-22), for `v0.4.0`; the GitHub repository's rename and the SVG
logo (task 059) remain.

Rename goose-rest to Plod before it goes on HttpArena. The joke is a framework named for
slowness at or near the top of the rankings, so a rival's result reads as "N% slower
than Plod".

## The brand

- Name: Plod. One syllable that sounds like a heavy step, and reads well in code
  (`plod::get`). In British slang "PC Plod" is a slow, dim policeman, which fits the
  joke.
- Mascot: Ari, a banana slug (genus *Ariolimax*). The logo is low-poly SVG built from
  triangles, in the style of Species in Pieces, and must animate well in FFFrames. A
  banana slug has four tentacles: two long upper ones with eyes at the tips and two short
  lower ones. The upper pair makes the silhouette recognizable, so draw all four. Until
  the SVG exists (task 059), the logo is the PNGs in `docs/assets/`.
- Slogan: "Takes its time, not yours." (2026-10-22: the comma form the logo uses,
  replacing "Takes its time. Not yours.")
- Benchmark line: "Slow by name only."
- Spare slogans: "No shell. No baggage." (lean memory: a slug is a snail without its
  shell), "In no hurry. Rarely behind.", "Somehow, still ahead.", "Nobody told the
  slug."
- Slogans hold no figures. Numbers go in the benchmark tables with how they were
  measured, so the slogans never go stale.
- Reserve name: Glacial ("at a glacial pace"; an icy-coloured slug still fits).

## Names ruled out

Collisions found by a GitHub repository-name search on 2026-10-18 and 2026-10-19:

| Name | Reason |
|---|---|
| Tardy | tardy-org's zzz, a Zig framework for networked services, on its tardy runtime; same field and the same joke |
| Tardigrade | An active TypeScript agent framework |
| Saunter | asyncapi/saunter, an API documentation generator |
| Slowpoke | A Pokémon trademark |
| Slowloris | A well-known HTTP denial-of-service attack |
| Tortoise, Escargot, Sloth, Helix, Hibernate, Terrapin, Glacier | An established ORM, JS engine, tool, or service of that name |
| Slug | A GPU text renderer; usable only in a compound such as Banana Slug |

Trudge is free on GitHub and is the second choice. Dawdle stays a word for copy:
hashicorp/dawdle, a small network-throttling test proxy, muddies the joke for an HTTP
server. Also set aside: Amble, Torpid (sounds like "torpedo"), Drowsy and Sleepwalk
(sleepy suggests downtime), Lento, Dormouse, Pitchdrop, Snailfish, and Driftwood.

## The name check (2026-10-22)

Plod passes as the earlier names were judged: no web framework, HTTP, or server project
is named plod.

| Where | Found |
|---|---|
| crates.io | `plod`: a "plain old data" derive macro, dormant since 2024-05; `plod-http` and `plod-rest` are free |
| npm | `plod`: a plop-templates CLI from 2018, abandoned |
| PyPI | `plod`: "Pythonic Lists of Dictionaries", from the Python 2 era; `plod-http` and `plod-rest` are free |
| GitHub | The user `plod` is a personal account; no `plod` organization, and no notable repository (26 stars at most, none HTTP) |
| Domains | plod.dev registered (Cloudflare, no site); plod.io registered and parked until 2027-05; plod.sh appears free |
| Trademarks | EUIPO and USPTO not queried directly. Web searches found no PLOD mark in classes 9 or 42, only PLODES, PLODOS, and PLODICA, in jewelry, cosmetics, and furniture |

## The repository

Imports name the repository, so `github.com/kaitk/goose-rest` stays in every import,
link, and script until GitHub renames it. Then, in one commit:

```sh
scripts/rename-repo-url.sh --dry-run   # lists every file and line it would change
scripts/rename-repo-url.sh
scripts/test.sh
```

GitHub redirects the old URL after a rename, for git clones too, so a program pinned to
`goose-rest@v0.3.4` or earlier keeps building.

## Acceptance criteria

- [x] Plod is checked beyond GitHub: crates.io, npm, PyPI, a `plod` GitHub
      organization, the .dev, .io, and .sh domains, and EUIPO and USPTO for software
      marks. If it fails, Trudge gets the same check. Unchecked: a manual TMview and
      USPTO search for PLOD in classes 9 and 42.
- [ ] Ari's logo exists as an SVG, with the horizontal, icon, and favicon variants
      (task 059; PNGs in `docs/assets/` meanwhile)
- [x] A decision in `docs/decisions.md` records the name and the reason
- [ ] The repository, package, imports in every root under `test/`, `examples/`,
      `docs/tutorial/`, `docs/best-practices/`, `spikes/`, and `bench/`, the scripts,
      `README.md`, `CHANGELOG.md`, and `docs/` use the new name, in their own commit.
      Done but for the repository's URL, which waits on GitHub's rename and
      `scripts/rename-repo-url.sh`. Recorded results and the benchmark server
      `bench/rest/goose-rest/` keep the name they were measured under.
- [x] `scripts/test.sh` passes
- [ ] `v0.4.0` is tagged, and the README's quick start, which imports it, builds
