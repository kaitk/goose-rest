# 055: A documentation site

Status: todo (asked for 2026-10-20)

[Aegon's guide](https://udaykhare09.github.io/Aegon/) is a site with a sidebar and a
page per feature, and each page follows one shape: a sentence on what the feature does,
the shortest working example, a table of options with their defaults, then the details.
A reader finds a feature and uses it without reading around it. goose-rest's docs hold
the same facts, but spread over a long `docs/reference.md`, the tutorial, and the best
practices, read as Markdown on GitHub.

Take the shape, not the adjectives: Aegon's pages also say "ultra", "enterprise-grade",
and "zero-overhead" where a number would do, which the google-style skill already
rules out.

## Steps

1. Pick the generator. It must build from the Markdown in `docs/` as it is, render
   Mermaid, and work for a developer on a clean machine without LLM tools. Candidates:
   mdBook (one binary, Mermaid through a preprocessor) and VitePress (Node, the
   generator Aegon uses). Record the choice in `docs/decisions.md`.
2. Split `docs/reference.md` into a page per area: routes, middleware (one page each),
   extractors, later calls, lanes, errors, testing. Each page opens with the sentence,
   the example, and the options table.
3. The tutorial, the best practices, and the generator reference as sections of the
   site, their pages unchanged.
4. Publish to GitHub Pages from `main`, built by CI, with links checked.

The site's address is `kaitk.github.io/plod` (2026-10-23), GitHub Pages' default for
the repository, so it needs no domain. Once the site is up, it becomes the repository's
homepage on GitHub.

## Acceptance criteria

- [ ] The generator chosen and recorded in `docs/decisions.md`
- [ ] Every reference page opens with what it does, an example, and its options table
- [ ] The site builds locally with one documented command, and in CI on every push
- [ ] Broken links fail the build
- [ ] `README.md` links to the site, and the repository's homepage is set to it
