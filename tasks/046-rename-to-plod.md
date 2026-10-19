# 046: Rename to Plod

Status: todo. Not started; the name is chosen, and the logo comes before the rename.

Rename goose-rest to Plod before it goes on HttpArena. The joke is a framework named for
slowness at or near the top of the rankings, so a rival's result reads as "N% slower
than Plod".

## The brand

- Name: Plod. One syllable that sounds like a heavy step, and reads well in code
  (`plod.App`). In British slang "PC Plod" is a slow, dim policeman, which fits the joke.
- Mascot: Ari, a banana slug (genus *Ariolimax*). The logo is low-poly SVG built from
  triangles, in the style of Species in Pieces, and must animate well in FFFrames. A
  banana slug has four tentacles: two long upper ones with eyes at the tips and two short
  lower ones. The upper pair makes the silhouette recognizable, so draw all four.
- Slogan: "Takes its time. Not yours."
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

## Acceptance criteria

- [ ] Plod is checked beyond GitHub: crates.io, npm, PyPI, a `plod` GitHub
      organization, the .dev, .io, and .sh domains, and EUIPO and USPTO for software
      marks. If it fails, Trudge gets the same check.
- [ ] Ari's logo exists as an SVG, with the horizontal, icon, and favicon variants
- [ ] A decision in `docs/decisions.md` records the name and the reason
- [ ] The repository, package, imports in every root under `test/`, `examples/`,
      `docs/tutorial/`, `docs/best-practices/`, `spikes/`, and `bench/`, the scripts,
      `README.md`, `CHANGELOG.md`, and `docs/` use the new name, in their own commit
- [ ] `scripts/test.sh` passes
