# 4. JSON bodies

goose-http reads a request into a buffer of 8 KB, and a JSON body that fits there with
its head reaches the route whole, as most do
([goose-http's request bodies](https://github.com/kaitk/goose-http/blob/main/docs/patterns.md#request-bodies)).
A longer one is gathered when the route asks for it: [Large bodies](10-large-bodies.md).

## Read by hand

`rest::take<T>(cx)` is goose-rest's extractor by type, Actix's `web::Json<T>`. It calls
the overload `rest::from_request(cx, v: const T?)` that you, or the generator, declare
for `T`. `v` is always null; only its type matters.

For a body read by hand, the overload passes a reader to `rest::json_body`, which
answers 415 unless the request says `application/json`, and 400 `invalid_body` for a body
the reader refuses. A reader collects each member as a slice, checks them, and builds the
struct once at the end: a struct holding a string can't be filled field by field. From
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
        if rest::on(cx, "POST", "/projects") {
            rest::route(cx) {
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

`T` is given explicitly, `take<ProjectCreate>`: Goose can't infer it from what the result
is assigned to.

## Generated from a schema

Writing readers by hand gets old. The generator writes the struct, the reader, the
`format` writer, and the `from_request` overload for each schema in an OpenAPI
document's `components`. A document without `paths` gets only those, and the routes stay
yours. From [`04-json/types`](04-json/types/api.json):

```json
  "components": {
    "schemas": {
      "Project": {
        "type": "object",
        "required": ["id", "name"],
        "properties": {
          "id": { "type": "integer", "minimum": 1 },
          "name": { "type": "string", "minLength": 1, "maxLength": 64 },
          "color": { "type": "string", "maxLength": 7 }
        }
      },
```

Generate `api_gen.goose` beside it, and import it from the root as `.api_gen`:

```sh
goose build -o build/goose-rest gen/main.goose        # once, from this repository
build/goose-rest gen docs/tutorial/04-json/types/api.json -o docs/tutorial/04-json/types/api_gen.goose
```

The generated namespace is `api`. `Project` becomes a struct with `has_color` before its
optional `color`, and its strings limited arrays of four bytes per code point:

```rust
struct Project {
    id: i64,
    name: u8[..256],
    has_color: bool,
    color: u8[..28],
}
```

The hand-written routes use the generated types as their own:

```rust
        if rest::on(cx, "POST", "/projects") {
            rest::route(cx) {
                let body = rest::take<api::ProjectCreate>(cx);
                let p .= cx.app.projects.push(api::Project {
                    id: cx.app.projects.len + 1, name: body.name, has_color: body.has_color, color: body.color,
                });
                rest::json(cx, 201, p);
            };
```

The generated reader names the field and the check that failed, and the writer leaves
out an optional field that isn't there:

```text
POST /projects 201 {"id":1,"name":"goose","color":"#00ff00"}
POST /projects 201 {"id":2,"name":"gander"}
POST /projects 400 {"error":"invalid_body","detail":"color: maxLength","at":39}
POST /projects 400 {"error":"invalid_body","detail":"unknown member","at":26}
```

The generator's file is never edited by hand: change the schema and regenerate.
`scripts/test.sh` regenerates every `api_gen.goose` in this repository and fails when one
differs from the committed file. The [generator reference](../generator.md#the-subset)
lists the schema keywords it reads, and refuses anything else with the construct's JSON
pointer rather than drop it.

---

[Index](README.md) · Previous: [3. Answers and errors](03-errors.md) · Next:
[5. The API from a schema](05-schema.md)
