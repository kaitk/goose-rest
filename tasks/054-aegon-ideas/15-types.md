# 15: Foundational types

Status: todo (asked for 2026-10-20)

Aegon's [foundational types](https://udaykhare09.github.io/Aegon/guide/data/types)
(read 2026-10-20) are fixed-size values that its JSON, validation, SQL, and Redis layers
all accept:

| Type | Size | What it does |
|---|---|---|
| UUID | 16 B | v4 and v7 (time-ordered, with its timestamp), parse, format, nil check |
| DateTime | 8 B | UTC in micro- or nanoseconds; ISO 8601 parse and format |
| Date | 4 B | Civil calendar (Hinnant's algorithms); add days; `YYYY-MM-DD` |
| Time | 8 B | Time of day in microseconds |
| Decimal | 16 B | Fixed point at a precision and scale, like SQL `DECIMAL(18, 4)`, with exact arithmetic |
| IpAddress | 16 B | IPv4 or IPv6; CIDR membership; private and loopback checks |
| MacAddress | 6 B | Parse and format |
| Blob | variable | Bytes, with hex, Base64, and SQL hex encoding |
| Hash256 | 32 B | A SHA-256 digest, hex, compared in constant time |

goose-rest checks these formats today and keeps the text: a `uuid` or `date-time`
property is a `u8[..n]` that `check.goose` validates (`docs/generator.md`). Types would
make them values, smaller and comparable without parsing again:

- **The generator** maps `format: uuid` to the UUID type, `date-time` to DateTime,
  `date` to Date, and so on, with the readers and writers converting. `ipv4` and
  `ipv6` come with them.
- **goose-postgres** decodes `uuid`, `timestamptz`, `date`, `time`, `numeric`, and
  `inet` into them. They're its 🔴 "More types" row, so both repositories agree on the
  types.
- **Validation** (subtask 13) gets not nil, past, and future on them.

The types are flat structs with no heap, so they cross threads and add nothing at run
time beyond the conversions. They're shared by goose-rest, goose-postgres, goose-sqlite,
and a Redis client, so they likely go in a package of their own. Goose's stdlib has
Base64 (`stdlib/base64.goose`) and no 128-bit integer, so Decimal is two 64-bit halves
or an `i64` with a smaller precision; decide which.

## Acceptance criteria

- [ ] Where they live decided, with goose-postgres's agreement, in `docs/decisions.md`
- [ ] UUID (v4, v7), DateTime, Date, Time, Decimal, and IpAddress, each with parse,
      format, and comparison, tested against their RFCs' examples
- [ ] The generator mapping each format to its type, behind no option or one, decided
- [ ] Decimal's representation and range recorded
