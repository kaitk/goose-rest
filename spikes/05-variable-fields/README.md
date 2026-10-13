# 05: Filling variable-size fields from JSON

Checks an open question in [the plan](../../docs/plan.md). Can a reader fill a struct's `u8[]` fields one key at a
time, in whatever order the JSON gives them? Or does in-place construction (spec
§4.2-4.3) force it to collect the values first and build the struct once?

Goose commit: `a6249a4`.

```sh
GOOSE=<build>/goose
$GOOSE main.goose
```

## Verdict: build once; collecting costs nothing

A `u8[]` field can't be filled after construction, as spec §4.4 says. It can't grow,
can't be assigned, and the struct holding it can't be assigned whole either:

```goose
struct P { id: i64, name: u8[], note: u8[] }
var p = P { id: 1, name: [], note: [] };
p.name.append("goose");                    // error: .append is not available on u8[]
p.name = "goose";                          // error: a value of type u8[] is frozen at construction (§4.4)
p = P { id: 2, name: "goose", note: "" };  // error: a value of type P is frozen at construction (§4.4)
```

Collecting the values first costs no copy. `json::read_string` returns a slice: of the
text for a string without escapes, and of `scratch` for one it decoded. The reader keeps
one slice per field as each key arrives, in any order, and builds the struct once at
the end. Each field's bytes are copied once, into the struct at its destination.
`main.goose` prints:

```text
true 3
7 [goose] [#ff0000]
8 [duck] []
9 [swan] []
```

Keys arrive in different orders, a field can be missing, an unknown key is skipped, and
a repeated key rebinds its slice, so the last one wins.

## The workable pattern

```goose
fn read_project(r: json::Reader&, scratch: u8[>..]&) -> Project {
    var name = r.text[..0];     // rooted at the reader's text, not at a literal
    json::each_member(r) { key =>
        if key == "name" { name = json::read_string(r, scratch); }
        else { json::skip(r); }
    };
    return Project { name: name, .. };
}

all.push(read_project(r, scratch));   // built in place in all
```

- Take the reader by reference. Start each slice as `r.text[..0]`. Starting from `""`
  fails, because the slice is then rooted at static data and can't be rebound to the
  reader's: "re-binding name with a reference rooted at a different scope depth is not
  supported". With a local `Reader`, `r.text[..0]` fails the same way when the text is a
  literal.
- `scratch` belongs to the caller and holds the decoded strings until the struct is
  built. Clear it per request, not per field.
- Where the slices can't be kept, copy each value onto a `strings: u8[>..]` and
  record its start and end. Then build the struct from `strings[a..b]` and clear
  `strings` after the push. That version also works on `a6249a4`.
- A `u8[..k]` field (`maxLength`) is a limited array, which can be appended to in
  place. Clear it before appending, or a repeated key overflows its capacity, and an
  append past capacity aborts.
