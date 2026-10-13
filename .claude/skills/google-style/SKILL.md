---
name: google-style
description: Writing and editing guide for prose in this repository, based on the Google developer documentation style guide. Use it whenever you write or revise Markdown under docs/, tasks/, datamodel/ or a README, and when asked to make any text clearer, shorter, or less formulaic. Covers structure, sentence-level clarity, words and patterns to cut, formatting, and how to keep recorded decisions accurate while editing.
---

# Writing style

Source: https://developers.google.com/style. The rules below adapt it to this repository.

Readers here are developers joining the project and future agents working on it. They
read these docs to learn what was decided and why, then act on it. Write so they can
find the decision fast, trust it, and know what to argue with if they disagree.

Each rule has a reason. When a rule and the reason conflict in a particular sentence,
follow the reason.

## Before you write

1. Identify the reader, the one thing they need from this text, and the format (repo
   doc, task file, README, code comment).
2. List what must stay exact: decisions, names, numbers, versions, commands, and whether
   something is decided, proposed, or open.
3. Edit in order: structure, then paragraphs, then sentences. Polishing sentences in a
   section that should be deleted wastes effort.

## Sentences

- **Name the actor, in active voice.** "The trigger sets `updated_at`", not "`updated_at`
  is set". Readers need to know which component is responsible, because that is where
  they will look when it breaks.
- **Address the reader in instructions; describe the system in design text.** Workflow
  docs say "Run `bun run db:migrate`". Architecture docs say "CI runs migrations". Don't
  turn a description of the system into an instruction, or the reverse.
- **Present tense for defined behavior.** "The helper returns the scope", not "will
  return".
- **One idea per sentence.** A dash or semicolon joining two clauses is often two
  sentences. Split it when each half stands on its own.
- **Lead with the point.** Put the decision or answer first, the reasoning after. A
  reader skimming the first line of each paragraph should get the gist.

## Keep status exact

Editing must never change what a sentence commits to. These distinctions carry the
meaning of the docs, so preserve them exactly:

- Decided vs. proposed vs. open. Don't turn "we could" into "we do", or an open question
  into a settled one, for the sake of flow.
- **must** (requirement), **should** (recommendation), **can** (option).
- Implemented vs. planned. `architecture/` marks planned items; keep those markers.
- Numbers, versions, commands, file paths, and identifiers exactly as they are.

If you find two docs that contradict each other, flag it rather than silently picking one
while copyediting. `AGENTS.md` requires docs to follow recorded decisions.

## Cut what carries no information

Remove a word when the sentence means the same without it. Common candidates:

- Filler: simply, just, easily, obviously, of course, clearly, note that, it's worth
  noting, actually, basically, essentially, really, very, quite.
- Marketing adjectives with no measurable meaning: robust, seamless, powerful,
  comprehensive, cutting-edge, leverage, utilize, streamline, unlock, delve.

These are candidates, not banned strings. "Just-in-time" and "a very specific limit" can
stay if the word does work. Replace a vague adjective with the fact behind it: not "fast",
but "one indexed range query".

| Instead of                       | Write                                   |
| -------------------------------- | --------------------------------------- |
| "There is a column that stores…" | "The `x` column stores…"                |
| "It is possible to…"             | "You can…"                              |
| "In order to"                    | "To"                                    |
| "A number of"                    | The number                              |
| "e.g." / "i.e." / "etc."         | "for example" / "that is" / "and so on" |
| "May potentially"                | "May"                                   |
| "Since" / "as" meaning because   | "Because"                               |
| "As mentioned above"             | A link to the section                   |
| "Click here"                     | Link text naming the destination        |

## Patterns that make text read as generated

Readers skim past text that sounds generated, and they stop trusting the rest of the
page. Check for these, and rewrite only when the pattern adds nothing:

- **Closing summaries** that repeat the section. End when the content ends.
- **Tricolons.** "Clear, concise, and effective." Keep the one word that carries
  meaning.
- **Contrast framing.** "Not just X, but Y." "It's not X — it's Y." State Y.
- **Pivot phrases.** "The key insight is", "Here's the thing", "That said". Start with
  the point.
- **Hedge stacks.** "This might potentially be somewhat risky." State the risk, or
  state that it is unknown and what would settle it.
- **False balance.** "Both have merit; it depends on your needs." Recommend one, and name
  the condition that would change the recommendation.
- **Em-dash chains.** One dash in a paragraph is fine. Several read as a tic; use
  periods, commas, or parentheses.
- **Decorative bold.** Bold labels a list item or introduces a term. It does not stress
  words mid-sentence.
- **Rhetorical-question headings.** "Why integers?" becomes "Timestamps are integer
  milliseconds".
- **Over-structuring.** A three-sentence explanation doesn't need a heading, bullets, and
  a table. Use prose when the ideas connect; use lists when they are separate items.

## Formatting

- Sentence-case headings: "Schema and migrations", not "Schema And Migrations".
- Numbered lists for steps in order; bullets for sets where order carries no meaning.
- Tables for comparisons and mappings readers scan across rows. Keep cells short; a
  paragraph in a cell belongs in the text.
- Code, table, column, file, command, and env var names in backticks.
- Oxford comma. Contractions are fine and keep the tone human.
- Define an abbreviation on first use unless every developer knows it (SQL, UUID, CI).
- Wrap Markdown at about 90 characters, matching the existing docs.

## Precision

- Prefer the specific: "applies all migrations to an empty database", not "runs checks".
- Name the trade-off: "text IDs cost 20 more bytes per key and are readable in a
  console", not "text IDs are a trade-off".
- Software doesn't want, know, or decide. "The migrator skips applied files", not "the
  migrator knows which files ran".
- Use absolute dates ("2026-09-24"), never "recently" or "last week". Docs outlive the
  week they were written in.

## Repository conventions

- **Where things go.** `docs/product.md`: scope. `docs/architecture/`: decisions and
  their reasons. `docs/hosting.md`: platform limits. `docs/migrations.md`: how to change
  the schema. `datamodel/README.md`: the diagram workflow. `tasks/`: work items, in the
  format in `tasks/README.md`. Put each fact in one place and link to it from the others.
- **Decisions come with reasons.** A decision in `architecture/` states what was chosen
  and the reason in one or two sentences, including what was rejected when that matters.
  The reason is what lets a later reader tell whether the decision still holds.
- **Change docs with the code.** A change that contradicts a recorded decision updates
  the doc in the same commit (`AGENTS.md`).
- **Task files** are terse: a title, a status line, one or two sentences of context, and
  checkable acceptance criteria that name concrete outcomes.
- **Code comments** explain why, not what, and match the density of the surrounding code.

## Self-check

Before finishing, reread the text and check:

1. Can any sentence lose words without losing meaning?
2. Does any paragraph repeat an earlier one, or a fact recorded in another doc?
3. Where the reader expects a recommendation, is there one?
4. Would a reader who disagreed know exactly what to argue with?
5. Are actors, negations, conditions, numbers, and decided/proposed/open status unchanged
   from before your edit?
6. Do links and paths resolve, and do tables render?
