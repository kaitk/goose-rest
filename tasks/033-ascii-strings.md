# 033: Size ASCII strings in bytes, and a `format: ascii`

Status: todo (asked for 2026-10-15)

The generator writes a string with `maxLength: n` as `u8[..4n]`, since JSON Schema counts
code points and UTF-8 takes up to 4 bytes for one. A limited array always takes its full
capacity, so a field holds 4n bytes whatever its value, which costs most where a program
keeps many records ([generator](../docs/generator.md#the-subset), task 020's findings).
Where every valid value is ASCII, n bytes suffice.

Formats whose grammar is ASCII, as the generator checks them, need no change to a
schema: `uuid`, `date`, `date-time`, and `email` (a dot-atom address; `idn-email` is the
format for others). For free text, a schema says `format: ascii`. JSON Schema 2020-12
leaves `format` open: a validator that doesn't know a format ignores it, so the schema
stays valid for every tool, but only goose-rest refuses a value that isn't ASCII. A
schema that uses it accepts that other tools, such as a client's validator, don't check
it (2026-10-15).

## Acceptance criteria

- [ ] A string of `format` `uuid`, `date`, `date-time`, `email`, or `ascii`, with
      `maxLength: n`, is `u8[..n]`
- [ ] `format: ascii` is supported: the reader refuses a byte of 0x80 or more, as 400
      with `<field>: format`, as it refuses a malformed `uuid`
- [ ] The query and path readers check `format: ascii` the same way
- [ ] Generator tests cover each format's width, an `ascii` value refused, and the
      refusal's pointer and message
- [ ] `docs/generator.md` lists `ascii` with the formats, gives each format's width in
      its types table, and says other tools don't enforce `ascii`
- [ ] Optional, later: `pattern` limited to one anchored ASCII character class with
      `*`, `+`, or `{m,n}` (such as `^[a-z0-9-]+$`), checked byte by byte without a
      regex, and sized in bytes; any other `pattern` still refused while Goose's
      `regex` has no anchors. This changes the recorded decision to refuse `pattern`,
      so it updates `docs/generator.md` and the architecture doc with it.
