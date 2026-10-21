# 4. JSON bodies

A client creates a project by sending it as JSON, and the route needs it as a struct,
checked against the API's rules before any of it is used. `rest::take<T>` reads the body
into a `T`, through a reader you write by hand or one the generator writes from a
schema.

goose-http reads requests into an 8 KB buffer. A JSON body that fits alongside the
request head reaches the route in full, as most do
([goose-http's request bodies](https://github.com/kaitk/goose-http/blob/main/docs/patterns.md#request-bodies)).
A larger body is gathered when the route asks for it: [Large bodies](10-large-bodies.md).

## A reader written by hand

`rest::take<T>(cx)` is goose-rest's type-based extractor, like Actix's
`web::Json<T>`. It calls the `rest::from_request(cx, v: const T?)` overload that you or
the generator declare for `T`. `v` is always null; only its type matters.

For a hand-written body reader, the overload passes the reader to `rest::json_body`,
which answers 415 unless the request says `application/json`, or 400
`invalid_body` if the reader rejects the body. The reader collects the members as
slices, checks them, and builds the struct at the end: a struct that holds a string
can't be filled field by field. From
[`04-json/reader`](04-json/reader/main.goose):

```rust
struct ProjectCreate { name: u8[..256] }

fn read_create(r: json::Reader&, scratch: u8[>..]&) -> ProjectCreate {
    var name = r.text[..0];
    var has_name = false;
    json::each_member(r) { key =>
        if key == "name" { name = json::read_string(r, scratch); has_name = true; }
        else { json::fail(r, "unknown member"); }
    };
    if !has_name { json::fail(r, "name: required"); }
    let n = rest::code_points(name);
    if has_name && (n < 1 || n > 64) { json::fail(r, "name: length"); }
    if r.error.len > 0 { return ProjectCreate { name: "" }; }
    return ProjectCreate { name: name };
}

fn rest::from_request(cx, v: const ProjectCreate?) -> ProjectCreate {
    rest::json_body(cx) { r, scratch => read_create(r, scratch) }
}
```

```rust
        rest::post(cx, "/projects") {
            let body = rest::take<ProjectCreate>(cx);
            let p .= cx.app.projects.push(Project { id: cx.app.projects.len + 1, name: body.name });
            rest::json(cx, 201, p);
        };
```

```text
POST /projects 201 {"id":1,"name":"goose"}
POST /projects 400 {"error":"invalid_body","detail":"name: length","at":12}
POST /projects 400 {"error":"invalid_body","detail":"expected ',' or '}'","at":16}
POST /projects 415 {"error":"unsupported_media_type"}
```

Specify `T` explicitly, as in `take<ProjectCreate>`: Goose can't infer it from the
assignment target.

## A reader generated from a schema

Writing readers by hand gets repetitive. The generator writes the struct, reader,
`format` writer, and `from_request` overload for each schema in an OpenAPI document's
`components`. A document without `paths` generates only these; you still write the
routes. From [`04-json/types`](04-json/types/api.json):

```json
  "components": {
    "schemas": {
      "Project": {
        "type": "object",
        "required": ["id", "name"],
        "properties": {
          "id": { "type": "integer", "minimum": 1 },
          "name": { "type": "string", "minLength": 1, "maxLength": 64 },
          "color": { "type": "string", "format": "ascii", "maxLength": 7 }
        }
      },
```

Generate `api_gen.goose` beside it, and import it from the root as `.api_gen`:

```sh
goose build -o build/goose-rest gen/main.goose        # once, from this repository
build/goose-rest gen docs/tutorial/04-json/types/api.json -o docs/tutorial/04-json/types/api_gen.goose
```

The generated namespace is `api`. `Project` becomes a struct with a `has_color` flag
before the optional `color` field. Its strings use limited arrays. `name` has
`maxLength: 64`, which counts code points, and UTF-8 takes up to four bytes for one, so
the array holds 256 bytes. `color` has `format: ascii`, so it holds 7:

```rust
struct Project {
    id: i64,
    name: u8[..256],
    has_color: bool,
    color: u8[..7],
}
```

Hand-written routes can use the generated types directly:

```rust
        rest::post(cx, "/projects") {
            let body = rest::take<api::ProjectCreate>(cx);
            let p .= cx.app.projects.push(api::Project {
                id: cx.app.projects.len + 1, name: body.name, has_color: body.has_color, color: body.color,
            });
            rest::json(cx, 201, p);
        };
```

The generated reader reports the field and the check that failed. The writer omits
optional fields that are absent:

```text
POST /projects 201 {"id":1,"name":"goose","color":"#00ff00"}
POST /projects 201 {"id":2,"name":"gander"}
POST /projects 400 {"error":"invalid_body","detail":"color: maxLength","at":39}
POST /projects 400 {"error":"invalid_body","detail":"color: format","at":38}
POST /projects 400 {"error":"invalid_body","detail":"unknown member","at":26}
```

Never edit the generated file by hand: change the schema and regenerate.
`scripts/test.sh` regenerates every `api_gen.goose` in this repository and fails if any
result differs from the committed file. The [generator reference](../generator.md#4-the-subset)
lists the supported schema keywords. A construct outside that subset is refused with
its JSON pointer, never silently dropped.

## Size a string in bytes

A limited array always takes its full capacity, so without `format: ascii` a field with
`maxLength: n` holds `4n` bytes in every value, whatever its content. A `color` of
`maxLength: 7` would take 28 bytes to hold `#00ff00`, which is 7. In a request that
costs nothing, because the body lives only as long as the request. It adds up where a
program keeps records of the type, as a cache does, and in request state, which
every connection's slot holds ([State](08-state.md#worker-state)).

For example, a record with a 36-character `code` and a 7-character `color`:

| | `code` | `color` | Strings per record | 100,000 records |
|---|---|---|---|---|
| Without `format: ascii` | 144 bytes | 28 bytes | 172 bytes | 17.2 MB |
| With `format: ascii` | 36 bytes | 7 bytes | 43 bytes | 4.3 MB |

`format: ascii` tells the generator that every valid value is ASCII, so one byte holds
each character. The reader refuses any byte of 0x80 or more with 400 `color: format`,
the way it refuses a malformed `uuid`, as the fourth answer above shows. The formats
`uuid`, `date`, `date-time`, and `email` are ASCII by definition, so a string with one of
them and a `maxLength` takes `n` bytes without further help. Path and query parameters
accept `format: ascii` too.

Note these limits before you use it:

- A value that isn't ASCII is refused: a name with an accent, or an emoji, gets 400
  `<field>: format`.
- A client's own validator won't catch it first. `format` is an open keyword in JSON
  Schema, and tools that don't know `ascii` ignore it, so only goose-rest refuses the
  value.

It suits codes, identifiers, and tokens, not text that people type, such as a name or a
description. A program that keeps many of those holds them as ranges into one byte
array ([State](08-state.md#worker-state)).

---

[Index](README.md) · Previous: [3. Answers and errors](03-errors.md) · Next:
[5. The API from a schema](05-schema.md)
