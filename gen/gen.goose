// The generator: reads an OpenAPI 3.1 document and writes Goose source with a
// struct, a reader, and a writer for each schema under components.schemas.
// load() checks the whole document against the subset and lays the schemas
// out in flat tables; emit() writes the source from the tables. The subset
// and the code it becomes are in docs/generator.md.
namespace gen;

import std;
import json;
import .emit;
import .router;

// A value's kind, in Ty.kind.
let K_BOOL = 1;
let K_INT = 2;
let K_NUM = 3;
let K_STR = 4;
let K_ENUM = 5;
let K_OBJ = 6;
let K_ARR = 7;

// A string's format, in Ty.format.
let F_NONE = 0;
let F_DATE = 1;
let F_DATE_TIME = 2;
let F_UUID = 3;
let F_EMAIL = 4;

// A value's type and the checks on it. ref indexes objs for K_OBJ and enums
// for K_ENUM. A bound is the schema's number node, written into the
// generated code as the schema writes it.
struct Ty {
    kind: i64,
    ref: i64 = -1,
    nullable: bool = false,
    min_len: i64 = -1,
    max_len: i64 = -1,
    format: i64 = F_NONE,
    int32: bool = false,
    minimum: json::Node?,
    exclusive_minimum: json::Node?,
    maximum: json::Node?,
    exclusive_maximum: json::Node?,
    min_items: i64 = -1,
    max_items: i64 = -1,
}

// A property of an object. key is the name in the JSON, name the Goose
// field's; item is the element's type when ty is an array.
struct Field {
    key: const u8[:],
    name: const u8[:],
    ptr: const u8[:],
    required: bool,
    ty: Ty,
    item: Ty,
}

// An object schema, which becomes a struct. Its fields are
// fields[first..first + count].
struct Obj {
    name: const u8[:],
    ptr: const u8[:],
    node: json::Node&,
    closed: bool = false,
    first: i64 = 0,
    count: i64 = 0,
}

// A string enum, which becomes a Goose enum. Its values are the elements of
// values, and their variants variants[first..first + count].
struct Enum {
    name: const u8[:],
    ptr: const u8[:],
    values: json::Node&,
    first: i64 = 0,
    count: i64 = 0,
}

// A member of components.schemas, for $ref. obj or en is set where it
// became a struct or an enum.
struct Named {
    name: const u8[:],
    node: json::Node&,
    obj: i64 = -1,
    en: i64 = -1,
}

// A segment of a path template: literal text, or a parameter, {name}.
struct Seg { text: const u8[:], param: bool }

// Where a parameter is, in Param.at, as OpenAPI's in names it.
let P_PATH = 0;
let P_QUERY = 1;
let P_HEADER = 2;
let P_COOKIE = 3;
let PLACES = ["path", "query", "header", "cookie"];

// A parameter of an operation: its name, the Goose local or field it
// becomes, where it is, whether it's required, and its type: an integer
// with its bounds, a boolean, or a string with its lengths in code points.
struct Param {
    name: const u8[:],
    local: const u8[:],
    at: i64 = P_PATH,
    required: bool = true,
    int: bool,
    boolean: bool = false,
    int32: bool = false,
    has_minimum: bool = false,
    minimum: i64 = 0,
    has_maximum: bool = false,
    maximum: i64 = 0,
    min_len: i64 = -1,
    max_len: i64 = -1,
}

// An operation: its method as HTTP spells it, its handler's name, the
// security scheme it names ("" for none), and the object its JSON body is
// read as (-1 for none). Its path parameters are params[first..first +
// count], in the template's order, and its query, header, and cookie ones
// params[first_q..first_q + count_q], which the struct named params_type
// holds.
struct Op {
    method: const u8[:],
    handler: const u8[:],
    scheme: const u8[:],
    body: i64 = -1,
    first: i64 = 0,
    count: i64 = 0,
    first_q: i64 = 0,
    count_q: i64 = 0,
    params_type: const u8[:] = "",
}

// A path: its template, its segments segs[first_seg..first_seg + nsegs], its
// operations ops[first_op..first_op + nops] in the document's order, and the
// Allow they make.
struct Route {
    template: const u8[:],
    first_seg: i64,
    nsegs: i64,
    first_op: i64 = 0,
    nops: i64 = 0,
    allow: const u8[:] = "",
    is_static: bool = true,
}

// What a schema of each kind may say besides type, beyond the annotations.
let ANNOTATIONS = ["description", "title", "examples", "example", "deprecated", "$comment"];
let STRING_KEYWORDS = ["minLength", "maxLength", "format", "enum"];
let NUMBER_KEYWORDS = ["minimum", "maximum", "exclusiveMinimum", "exclusiveMaximum", "format"];
let OBJECT_KEYWORDS = ["properties", "required", "additionalProperties"];
let ARRAY_KEYWORDS = ["items", "minItems", "maxItems"];

// Goose's keywords (its lexer's list), which a field gets a trailing _ to
// avoid; inline is one only before fn.
let KEYWORDS = ["import", "namespace", "struct", "enum", "type", "fn", "thread_fn", "export",
    "simd", "recursive", "let", "var", "extern", "const", "pad", "reusable", "if", "else",
    "while", "for", "in", "loop", "block", "guard", "match", "return", "break", "continue",
    "as", "true", "false", "null", "self", "bool", "varint", "i8", "i16", "i32", "i64", "u8",
    "u16", "u32", "u64", "f32", "f64", "inline"];

// Names the generated readers use for their own parameters and temporaries,
// which no field may take.
let READER_NAMES = ["r", "scratch", "key", "s_", "e_", "ok_", "n_", "end_", "v_", "x_"];

// The methods an operation may have, as a path item names them, and as HTTP
// spells them.
let METHODS = ["get", "put", "post", "delete", "options", "head", "patch", "trace"];
let HTTP_METHODS = ["GET", "PUT", "POST", "DELETE", "OPTIONS", "HEAD", "PATCH", "TRACE"];

// What a path item, an operation, a parameter, and a request body may say.
let PATH_ITEM_KEYS = ["parameters", "summary", "description"];
let OPERATION_KEYS = ["operationId", "parameters", "requestBody", "security", "responses", "summary",
    "description", "tags", "deprecated", "externalDocs"];
let PARAMETER_KEYS = ["name", "in", "required", "schema", "description", "deprecated", "example", "examples"];
let BODY_KEYS = ["content", "required", "description"];

// Names dispatch uses for its own parameters and locals, which no path
// parameter may take, besides s and e followed by digits, its segments.
let DISPATCH_NAMES = ["cx", "state", "path", "m", "plain", "s_", "q_", "body_"];

// Names a parameters struct's from_request uses for its own, which no query,
// header, or cookie parameter may take.
let PARAMS_NAMES = ["cx", "v", "n_"];

// Header parameters OpenAPI says are ignored (OpenAPI 3.1 §4.8.12.1).
let IGNORED_HEADERS = ["accept", "content-type", "authorization"];

fn is_one_of(s: const u8[:], set: const u8[:][:]) -> bool {
    for x in set { if x == s { return true; } }
    return false;
}

fn is_upper(c: u8) -> bool { c >= 'A' && c <= 'Z' }
fn is_lower(c: u8) -> bool { c >= 'a' && c <= 'z' }
fn is_digit(c: u8) -> bool { c >= '0' && c <= '9' }
fn is_alnum(c: u8) -> bool { is_upper(c) || is_lower(c) || is_digit(c) }

// Whether s is a Goose identifier.
fn is_ident(s: const u8[:]) -> bool {
    guard s.len > 0 && (is_upper(s[0]) || is_lower(s[0]) || s[0] == '_') else { return false; }
    for c in s { guard is_alnum(c) || c == '_' else { return false; } }
    return true;
}

// s in snake_case, appended to out: `billingAddress` and `billing-address`
// become billing_address, and `HTTPServer` http_server. False if s holds
// anything but letters, digits, '_', '-', '.' and spaces.
fn format_snake(out: u8[>..]&, s: const u8[:]) -> bool {
    for c, i in s {
        if is_upper(c) {
            let after_lower = i > 0 && (is_lower(s[i - 1]) || is_digit(s[i - 1]));
            let ends_run = i > 0 && is_upper(s[i - 1]) && i + 1 < s.len && is_lower(s[i + 1]);
            if (after_lower || ends_run) && out.len > 0 && out[out.len - 1] != '_' { out.push('_'); }
            out.push(c + ('a' - 'A'));
        } else if is_lower(c) || is_digit(c) || c == '_' {
            out.push(c);
        } else if c == '-' || c == '.' || c == ' ' {
            if out.len > 0 && out[out.len - 1] != '_' { out.push('_'); }
        } else {
            return false;
        }
    }
    return true;
}

// s in PascalCase, appended to out: each run of letters and digits starts
// with a capital, and one written all in capitals keeps only the first.
// `in-progress` becomes InProgress, `IN_PROGRESS` InProgress, and
// `billingAddress` BillingAddress. One that starts with a digit gets a V.
fn format_pascal(out: u8[>..]&, s: const u8[:]) {
    var i = 0;
    while i < s.len {
        while i < s.len && !is_alnum(s[i]) { i++; }
        let start = i;
        var lower = false;
        while i < s.len && is_alnum(s[i]) { if is_lower(s[i]) { lower = true; } i++; }
        if i == start { break; }
        for k in start..i {
            let c = s[k];
            if k == start {
                if is_digit(c) && out.len == 0 { out.push('V'); }
                out.push(if is_lower(c) { c - ('a' - 'A') } else { c });
            } else {
                out.push(if !lower && is_upper(c) { c + ('a' - 'A') } else { c });
            }
        }
    }
}

// Whether s can go between the quotes of a Goose and a JSON string literal
// as it is: no '"', '\' or control character.
fn is_plain(s: const u8[:]) -> bool {
    for c in s { guard c >= ' ' && c != '"' && c != '\\' && c != 0x7F else { return false; } }
    return true;
}

// A JSON pointer's reference token for key (RFC 6901): ~ and / escaped.
fn format_token(out: u8[>..]&, key: const u8[:]) {
    for c in key {
        if c == '~' { out.append("~0"); }
        else if c == '/' { out.append("~1"); }
        else { out.push(c); }
    }
}

// The element of list whose "name" is name, and its index; null and -1
// when there's none.
fn find_name(list: json::Node?, name: const u8[:]) -> json::Node?, i64 {
    var found: json::Node? = null;
    guard list else { return found, -1; }
    var k = 0;
    var at = -1;
    json::each(list) { p =>
        let n, ok = json::as_string(json::member(p, "name"));
        if ok && n == name { found .= p; at = k; }
        k++;
    };
    return found, at;
}

// The index of key in METHODS, or -1.
fn method_index(key: const u8[:]) -> i64 {
    for name, i in METHODS { if key == name { return i; } }
    return -1;
}

// Whether s is s or e followed by digits: the name of a segment's local in
// dispatch.
fn is_segment_name(s: const u8[:]) -> bool {
    guard s.len > 1 && (s[0] == 's' || s[0] == 'e') else { return false; }
    for c in s[1..] { guard is_digit(c) else { return false; } }
    return true;
}

// Reads the document and writes the source to out, dispatch calling the
// handlers in the namespace handlers. Returns "" or the first error, as
// "<JSON pointer>: <message>".
fn generate(text: const u8[:], ns: const u8[:], handlers: const u8[:], source: const u8[:], out: u8[>..]&) -> u8[] {
    var doc: json::Node[>..] = [];
    var decoded: u8[>..] = [];
    var strs: u8[>..] = [];              // the names and pointers the tables point into
    var named: Named[>..] = [];
    var objs: Obj[>..] = [];
    var enums: Enum[>..] = [];
    var fields: Field[>..] = [];
    var variants: (const u8[:])[>..] = [];
    var routes: Route[>..] = [];
    var segs: Seg[>..] = [];
    var ops: Op[>..] = [];
    var params: Param[>..] = [];

    fn fail(ptr: const u8[:], msg: const u8[:]) {
        return str(ptr, ": ", msg) from generate;
    }

    // A pointer: base, then each of the tokens, each escaped.
    fn ptr2(base: const u8[:], a: const u8[:], b: const u8[:]) -> const u8[:] {
        let at = strs.len;
        strs.append(base);
        strs.push('/');
        format_token(strs, a);
        if b.len > 0 { strs.push('/'); format_token(strs, b); }
        return strs[at..];
    }

    fn ptr1(base: const u8[:], a: const u8[:]) -> const u8[:] { ptr2(base, a, "") }

    // The names of all the types, for the uniqueness check.
    fn taken(name: const u8[:]) -> bool {
        for o in objs { if o.name == name { return true; } }
        for e in enums { if e.name == name { return true; } }
        return false;
    }

    fn type_name(name: const u8[:], ptr: const u8[:]) {
        guard is_ident(name) && !is_one_of(name, KEYWORDS) else {
            fail(ptr, "the name isn't a Goose identifier");
        }
        guard !taken(name) else { fail(ptr, "another type has this name"); }
    }

    // Parent + the property's name in PascalCase: the name of a type
    // declared inline.
    fn derived_name(parent: const u8[:], key: const u8[:], ptr: const u8[:]) -> const u8[:] {
        let at = strs.len;
        strs.append(parent);
        format_pascal(strs, key);
        let name = strs[at..];
        type_name(name, ptr);
        return name;
    }

    fn add_enum(name: const u8[:], ptr: const u8[:], values: json::Node&) -> i64 {
        let vptr = ptr1(ptr, "enum");
        let count = match values.val { Arr a => a.count, _ => 0 };
        guard count > 0 else { fail(vptr, "an enum needs an array of one or more strings"); }
        let first = variants.len;
        json::each(values) { v =>
            let s, ok = json::as_string(v);
            guard ok else { fail(vptr, "only string enums are supported"); }
            guard is_plain(s) else { fail(vptr, "an enum value with '\"', '\\' or a control character isn't supported"); }
            let at = strs.len;
            format_pascal(strs, s);
            let variant = strs[at..];
            guard variant.len > 0 else { fail(vptr, "an enum value needs a letter or digit"); }
            for k in first..variants.len {
                guard variants[k] != variant else { fail(vptr, str("two values make the variant ", variant)); }
            }
            variants.push(variant);
        };
        enums.push(Enum { name: name, ptr: ptr, values: values, first: first, count: count });
        return enums.len - 1;
    }

    fn add_obj(name: const u8[:], ptr: const u8[:], node: json::Node&) -> i64 {
        objs.push(Obj { name: name, ptr: ptr, node: node });
        return objs.len - 1;
    }

    fn check_keys(node: json::Node&, ptr: const u8[:], allowed: const u8[:][:], what: const u8[:]) {
        json::each(node) { m =>
            let k = m.key;
            guard k == "type" || is_one_of(k, ANNOTATIONS) || is_one_of(k, allowed) else {
                if k == "nullable" {
                    fail(ptr1(ptr, k), "nullable is OpenAPI 3.0's; write the type as [\"<type>\", \"null\"]");
                }
                fail(ptr1(ptr, k), str("not supported on ", what));
            }
        };
    }

    fn count_of(node: json::Node?, ptr: const u8[:], key: const u8[:]) -> i64 {
        let n = json::member(node, key);
        guard n else { return -1; }
        let v, ok = json::as_i64(n);
        guard ok && v >= 0 else { fail(ptr1(ptr, key), "must be a non-negative integer"); }
        return v;
    }

    fn bound(node: json::Node?, ptr: const u8[:], key: const u8[:], int: bool) -> json::Node? {
        let n = json::member(node, key);
        guard n else { return null; }
        if int {
            let v, ok = json::as_i64(n);
            guard ok else { fail(ptr1(ptr, key), "must be an integer on an integer"); }
        } else {
            let v, ok = json::as_f64(n);
            guard ok else { fail(ptr1(ptr, key), "must be a number"); }
        }
        return n;
    }

    // The component a $ref names, as an index into named.
    fn target(node: json::Node&, ptr: const u8[:]) -> i64 {
        let rptr = ptr1(ptr, "$ref");
        let ref, ok = json::as_string(json::member(node, "$ref"));
        guard ok else { fail(rptr, "must be a string"); }
        let prefix = "#/components/schemas/";
        guard ref.len > prefix.len && ref[..prefix.len] == prefix else {
            fail(rptr, "only #/components/schemas/<name> is supported");
        }
        let name = ref[prefix.len..];
        for n, i in named { if n.name == name { return i; } }
        fail(rptr, "no such schema");
        return -1;
    }

    // A schema's type: "string", or ["string", "null"], which is nullable.
    fn type_name_of(tnode: json::Node&, tptr: const u8[:]) -> const u8[:], bool {
        let s, is_str = json::as_string(tnode);
        if is_str { return s, false; }
        match tnode.val { Arr a => {}, _ => fail(tptr, "must be a string or an array of strings") }
        var nullable = false;
        var count = 0;
        var chosen: json::Node? = null;
        json::each(tnode) { t =>
            let ts, ok = json::as_string(t);
            guard ok else { fail(tptr, "must be a string or an array of strings"); }
            if ts == "null" { nullable = true; } else { count++; chosen .= t; }
        };
        guard count == 1 else { fail(tptr, "one type besides \"null\" is supported"); }
        let c, cok = json::as_string(chosen);
        return c, nullable;
    }

    // The type of the schema at node, the property key of the object
    // parent. A $ref to an object or an enum is that type; one to any
    // other schema is read as that schema, through any chain of $refs.
    // An object or enum declared inline is added to the tables under the
    // name parent + key, which item appends Item to for an array's element.
    fn type_of(node0: json::Node&, ptr0: const u8[:], parent: const u8[:], key: const u8[:], item: bool) -> Ty {
        var node .= node0;
        var ptr = ptr0;
        var hops = 0;
        while json::member(node, "$ref") {
            json::each(node) { m =>
                guard m.key == "$ref" || is_one_of(m.key, ANNOTATIONS) else {
                    fail(ptr1(ptr, m.key), "not supported beside $ref");
                }
            };
            let t = target(node, ptr);
            if named[t].obj >= 0 { return Ty { kind: K_OBJ, ref: named[t].obj }; }
            if named[t].en >= 0 { return Ty { kind: K_ENUM, ref: named[t].en }; }
            hops++;
            guard hops <= named.len else { fail(ptr, "a cycle of $refs"); }
            node .= named[t].node;
            ptr = ptr1("#/components/schemas", named[t].name);
        }
        let tnode = json::member(node, "type");
        guard tnode else { fail(ptr, "a schema needs a type or a $ref"); }
        let tptr = ptr1(ptr, "type");
        let tname, nullable = type_name_of(tnode, tptr);
        var ty = Ty { kind: 0, nullable: nullable };
        let suffix = if item { "Item" } else { "" };
        if tname == "boolean" {
            check_keys(node, ptr, [], "a boolean");
            ty.kind = K_BOOL;
        } else if tname == "integer" || tname == "number" {
            let int = tname == "integer";
            check_keys(node, ptr, NUMBER_KEYWORDS, if int { "an integer" } else { "a number" });
            ty.kind = if int { K_INT } else { K_NUM };
            ty.minimum .= bound(node, ptr, "minimum", int);
            ty.exclusive_minimum .= bound(node, ptr, "exclusiveMinimum", int);
            ty.maximum .= bound(node, ptr, "maximum", int);
            ty.exclusive_maximum .= bound(node, ptr, "exclusiveMaximum", int);
            let f = json::member(node, "format");
            if f {
                let fs, ok = json::as_string(f);
                if int && ok && fs == "int32" { ty.int32 = true; }
                else if !(ok && (if int { fs == "int64" } else { fs == "float" || fs == "double" })) {
                    fail(ptr1(ptr, "format"), if int { "only int32 and int64 are supported" }
                        else { "only float and double are supported" });
                }
            }
        } else if tname == "string" {
            check_keys(node, ptr, STRING_KEYWORDS, "a string");
            let values = json::member(node, "enum");
            if values {
                for k in ["minLength", "maxLength", "format"] {
                    if json::member(node, k) { fail(ptr1(ptr, k), "not supported beside enum"); }
                }
                ty.kind = K_ENUM;
                ty.ref = add_enum(derived_name(parent, str(key, suffix), ptr), ptr, values);
                return ty;
            }
            ty.kind = K_STR;
            ty.min_len = count_of(node, ptr, "minLength");
            ty.max_len = count_of(node, ptr, "maxLength");
            let f = json::member(node, "format");
            if f {
                let fs, ok = json::as_string(f);
                ty.format = if !ok { -1 } else if fs == "date" { F_DATE } else if fs == "date-time" { F_DATE_TIME }
                    else if fs == "uuid" { F_UUID } else if fs == "email" { F_EMAIL } else { -1 };
                guard ty.format > 0 else { fail(ptr1(ptr, "format"), "only date, date-time, uuid and email are supported"); }
            }
        } else if tname == "object" {
            check_keys(node, ptr, OBJECT_KEYWORDS, "an object");
            ty.kind = K_OBJ;
            ty.ref = add_obj(derived_name(parent, str(key, suffix), ptr), ptr, node);
        } else if tname == "array" {
            guard !item else { fail(tptr, "an array of arrays isn't supported"); }
            check_keys(node, ptr, ARRAY_KEYWORDS, "an array");
            ty.kind = K_ARR;
            ty.min_items = count_of(node, ptr, "minItems");
            ty.max_items = count_of(node, ptr, "maxItems");
        } else {
            fail(tptr, str("unknown type ", tname));
        }
        return ty;
    }

    // The fields of objs[i], each checked and typed; adds the types they
    // declare inline to the tables.
    fn load_obj(i: i64) {
        let node .= objs[i].node;
        let ptr = objs[i].ptr;
        let props = json::member(node, "properties");
        guard props else { fail(ptr, "an object needs properties"); }
        match props.val { Obj o => {}, _ => fail(ptr1(ptr, "properties"), "must be an object") }
        let ap = json::member(node, "additionalProperties");
        if ap {
            let open, ok = json::as_bool(ap);
            guard ok else { fail(ptr1(ptr, "additionalProperties"), "only true and false are supported"); }
            objs[i].closed = !open;
        }
        let first = fields.len;
        json::each(props) { p =>
            let key = p.key;
            let pptr = ptr2(ptr, "properties", key);
            guard key.len > 0 && is_plain(key) else {
                fail(pptr, "a property name that's empty, or has '\"', '\\' or a control character, isn't supported");
            }
            let at = strs.len;
            guard format_snake(strs, key) else {
                fail(pptr, "a property name of letters, digits, '_', '-', '.' and spaces is supported");
            }
            if is_one_of(strs[at..], KEYWORDS) { strs.push('_'); }
            let name = strs[at..];
            guard is_ident(name) else { fail(pptr, str("the field name ", name, " isn't a Goose identifier")); }
            guard !is_one_of(name, READER_NAMES) else { fail(pptr, str("the field name ", name, " is one the reader uses")); }
            for f in fields[first..] {
                guard f.key != key else { fail(pptr, "a repeated property"); }
            }
            let ty = type_of(p, pptr, objs[i].name, key, false);
            var item = Ty { kind: 0 };
            if ty.kind == K_ARR {
                let items = json::member(p, "items");
                guard items else { fail(pptr, "an array needs items"); }
                item = type_of(items, ptr1(pptr, "items"), objs[i].name, key, true);
                guard !item.nullable else { fail(ptr2(pptr, "items", "type"), "a nullable element isn't supported"); }
            }
            fields.push(Field { key: key, name: name, ptr: pptr, required: false, ty: ty, item: item });
        };
        let count = fields.len - first;
        objs[i].first = first;
        objs[i].count = count;
        let req = json::member(node, "required");
        if req {
            let rptr = ptr1(ptr, "required");
            match req.val { Arr a => {}, _ => fail(rptr, "must be an array of property names") }
            json::each(req) { r =>
                let rk, ok = json::as_string(r);
                guard ok else { fail(rptr, "must be an array of property names"); }
                var found = false;
                for &f in fields[first..] { if f.key == rk { f.required = true; found = true; } }
                guard found else { fail(rptr, str("names ", rk, ", which isn't a property")); }
            };
        }
        // Each name the struct and its reader declare, once: the fields'
        // first, so a clash between two of them is the one reported.
        var names: (const u8[:])[>..] = [];
        for f in fields[first..] { names.push(f.name); }
        for f in fields[first..] {
            let at = strs.len;
            if !f.required { format(strs, "has_", f.name, " "); }
            if f.ty.nullable { format(strs, f.name, "_null "); }
            if f.ty.kind == K_OBJ || f.ty.kind == K_ARR { format(strs, f.name, "_at "); }
            each_split(strs[at..], ' ') { if it.len > 0 { names.push(it); } };
        }
        for a, k in names {
            for b in names[k + 1..] {
                guard a != b else { fail(ptr1(ptr, "properties"), str("two properties make the name ", a)); }
            }
        }
    }

    // Fails at the field that closes a cycle of objects holding each
    // other, inline or in arrays: a struct can't hold itself, and a
    // recursive reader can't keep its slices (docs/generator.md).
    fn check_cycles() {
        var state: i64[>..] = [];          // 0 unseen, 1 on the path, 2 done
        for o in objs { state.push(0); }
        var path: i64[>..<] = [];          // objects on the path
        var next: i64[>..<] = [];          // for each, the field to look at next
        for start in objs.len {
            if state[start] != 0 { continue; }
            state[start] = 1;
            path.push(start);
            next.push(0);
            while path.len > 0 {
                let o = path[path.len - 1];
                let k = next[next.len - 1];
                if k == objs[o].count {
                    state[o] = 2;
                    path.pop();
                    next.pop();
                    continue;
                }
                next[next.len - 1] = k + 1;
                let f = fields[objs[o].first + k];
                let to = if f.ty.kind == K_OBJ { f.ty.ref } else if f.ty.kind == K_ARR && f.item.kind == K_OBJ { f.item.ref } else { -1 };
                if to < 0 { continue; }
                guard state[to] != 1 else { fail(f.ptr, str("a cycle through ", objs[to].name, " isn't supported")); }
                if state[to] == 0 {
                    state[to] = 1;
                    path.push(to);
                    next.push(0);
                }
            }
        }
    }

    // name in snake_case in strs, as a Goose local or function name, which
    // must not be a keyword or one of reserved.
    fn local_name(name: const u8[:], ptr: const u8[:], reserved: const u8[:][:]) -> const u8[:] {
        let at = strs.len;
        guard format_snake(strs, name) else {
            fail(ptr, "a name of letters, digits, '_', '-', '.' and spaces is supported");
        }
        let local = strs[at..];
        guard is_ident(local) && !is_one_of(local, KEYWORDS) else {
            fail(ptr, str("the name ", local, " isn't a Goose identifier"));
        }
        guard !is_one_of(local, reserved) && !is_segment_name(local) else {
            fail(ptr, str("the name ", local, " is one the generated code uses"));
        }
        return local;
    }

    // The handler of the security scheme an operation requires: one
    // requirement of one scheme without scopes, as security_<scheme>, or ""
    // for none. node is the operation's list, or the document's.
    fn scheme_of(node: json::Node?, ptr: const u8[:], schemes: json::Node?) -> const u8[:] {
        guard node else { return ""; }
        let count = match node.val { Arr a => a.count, _ => -1 };
        guard count >= 0 else { fail(ptr, "must be an array of security requirements"); }
        guard count <= 1 else { fail(ptr, "one security requirement is supported, not alternatives"); }
        var start = 0;
        var end = 0;
        json::each(node) { req =>
            let n = match req.val { Obj o => o.count, _ => -1 };
            guard n == 1 else { fail(ptr1(ptr, "0"), "one scheme per requirement is supported"); }
            json::each(req) { s =>
                let sptr = ptr2(ptr, "0", s.key);
                let scopes = match s.val { Arr a => a.count, _ => -1 };
                guard scopes == 0 else { fail(sptr, "scopes aren't supported"); }
                guard json::member(schemes, s.key) else { fail(sptr, "no such scheme in components.securitySchemes"); }
                start = strs.len;
                strs.append("security_");
                guard format_snake(strs, s.key) && is_ident(strs[start..]) else {
                    fail(sptr, "a scheme name of letters, digits, '_', '-', '.' and spaces is supported");
                }
                end = strs.len;
            };
        };
        return strs[start..end];
    }

    // Where the parameter object p is: one of PLACES.
    fn place_of(p: json::Node&, pptr: const u8[:]) -> i64 {
        let where, ok = json::as_string(json::member(p, "in"));
        guard ok else { fail(ptr1(pptr, "in"), "must be a string"); }
        for s, i in PLACES { if s == where { return i; } }
        fail(ptr1(pptr, "in"), str("must be path, query, header, or cookie, not ", where));
        return -1;
    }

    // Checks a parameter object of the path whose segments start at
    // first_seg: a path parameter is required and named in the template, and
    // a header parameter isn't one OpenAPI ignores.
    fn check_param(p: json::Node&, pptr: const u8[:], first_seg: i64, nsegs: i64) {
        json::each(p) { k =>
            guard is_one_of(k.key, PARAMETER_KEYS) else { fail(ptr1(pptr, k.key), "not supported on a parameter"); }
        };
        let at = place_of(p, pptr);
        let name, nok = json::as_string(json::member(p, "name"));
        guard nok && name.len > 0 && is_plain(name) else {
            fail(ptr1(pptr, "name"), "must be a string without '\"', '\\' or a control character");
        }
        let r = json::member(p, "required");
        let req, rok = json::as_bool(r);
        guard rok || !r else { fail(ptr1(pptr, "required"), "must be true or false"); }
        if at == P_HEADER {
            var lower: u8[>..] = [];
            for c in name { lower.push(if is_upper(c) { c + ('a' - 'A') } else { c }); }
            guard !is_one_of(lower, IGNORED_HEADERS) else {
                fail(ptr1(pptr, "name"), str("OpenAPI ignores a header parameter named ", name));
            }
        }
        guard at == P_PATH else { return; }
        var found = false;
        for s in segs[first_seg..first_seg + nsegs] { if s.param && s.text == name { found = true; } }
        guard found else { fail(ptr1(pptr, "name"), "names no parameter of the path"); }
        guard rok && req else { fail(pptr, "a path parameter must have required: true"); }
    }

    // The parameter p, named name, at where: an integer, with minimum,
    // maximum and format; a string, with minLength and maxLength off the
    // path; or a boolean, off the path.
    fn param_of(p: json::Node&, pptr: const u8[:], name: const u8[:], where: i64) -> Param {
        let schema = json::member(p, "schema");
        guard schema else { fail(pptr, "a parameter needs a schema"); }
        let sptr = ptr1(pptr, "schema");
        let local = local_name(name, ptr1(pptr, "name"), if where == P_PATH { DISPATCH_NAMES } else { PARAMS_NAMES });
        let req, rok = json::as_bool(json::member(p, "required"));
        let t, ok = json::as_string(json::member(schema, "type"));
        if where == P_PATH {
            guard ok && (t == "integer" || t == "string") else {
                fail(sptr, "a path parameter's schema is an integer or a string");
            }
        } else {
            guard ok && (t == "integer" || t == "string" || t == "boolean") else {
                fail(sptr, "a parameter's schema is an integer, a string, or a boolean");
            }
        }
        var pp = Param { name: name, local: local, at: where, required: rok && req, int: t == "integer",
                         boolean: t == "boolean" };
        if t == "boolean" {
            check_keys(schema, sptr, [], "a boolean parameter");
            return pp;
        }
        if t == "string" {
            if where == P_PATH { check_keys(schema, sptr, [], "a path parameter's string"); }
            else { check_keys(schema, sptr, ["minLength", "maxLength"], "a string parameter"); }
            pp.min_len = count_of(schema, sptr, "minLength");
            pp.max_len = count_of(schema, sptr, "maxLength");
            return pp;
        }
        check_keys(schema, sptr, ["minimum", "maximum", "format"], "an integer parameter");
        let f = json::member(schema, "format");
        if f {
            let fs, fok = json::as_string(f);
            guard fok && (fs == "int32" || fs == "int64") else { fail(ptr1(sptr, "format"), "only int32 and int64 are supported"); }
            pp.int32 = fs == "int32";
        }
        let lo, has_lo = json::as_i64(bound(schema, sptr, "minimum", true));
        let hi, has_hi = json::as_i64(bound(schema, sptr, "maximum", true));
        pp.has_minimum = has_lo;
        pp.minimum = lo;
        pp.has_maximum = has_hi;
        pp.maximum = hi;
        return pp;
    }

    // The index of the parameter in list named name at where, or -1.
    fn index_at(list: json::Node?, name: const u8[:], where: i64, ptr: const u8[:]) -> i64 {
        guard list else { return -1; }
        var k = 0;
        json::each(list) { p =>
            let n, ok = json::as_string(json::member(p, "name"));
            if ok && n == name && place_of(p, ptr) == where { return k; }
            k++;
        };
        return -1;
    }

    // Adds the query, header, and cookie parameters of list, at lptr, to
    // params: those that other, the operation's own list, doesn't declare
    // again, or all when other is null.
    fn add_params(list: json::Node?, lptr: const u8[:], other: json::Node?) {
        guard list else { return; }
        var k = 0;
        json::each(list) { p =>
            let pptr = ptr1(lptr, str(k));
            let where = place_of(p, pptr);
            if where != P_PATH {
                let given, nok = json::as_string(json::member(p, "name"));
                guard index_at(list, given, where, pptr) == k else { fail(pptr, "a repeated parameter"); }
                if index_at(other, given, where, pptr) < 0 { params.push(param_of(p, pptr, given, where)); }
            }
            k++;
        };
    }

    // The object component a request body is read as.
    fn body_of(rb: json::Node&, bptr: const u8[:]) -> i64 {
        json::each(rb) { k =>
            guard is_one_of(k.key, BODY_KEYS) else { fail(ptr1(bptr, k.key), "not supported on a request body"); }
        };
        let req, rok = json::as_bool(json::member(rb, "required"));
        guard rok && req else { fail(bptr, "a request body must have required: true"); }
        let content = json::member(rb, "content");
        guard content else { fail(bptr, "a request body needs content"); }
        let cptr = ptr1(bptr, "content");
        json::each(content) { c =>
            guard c.key == "application/json" else { fail(ptr1(cptr, c.key), "only application/json is supported"); }
        };
        let media = json::member(content, "application/json");
        guard media else { fail(cptr, "a request body needs application/json"); }
        let mptr = ptr1(cptr, "application/json");
        json::each(media) { k =>
            guard k.key == "schema" else { fail(ptr1(mptr, k.key), "not supported on a media type"); }
        };
        let schema = json::member(media, "schema");
        guard schema else { fail(mptr, "a media type needs a schema"); }
        let sptr = ptr1(mptr, "schema");
        guard json::member(schema, "$ref") else { fail(sptr, "a body is a $ref to an object component"); }
        json::each(schema) { k =>
            guard k.key == "$ref" || is_one_of(k.key, ANNOTATIONS) else { fail(ptr1(sptr, k.key), "not supported beside $ref"); }
        };
        let t = target(schema, sptr);
        guard named[t].obj >= 0 else { fail(ptr1(sptr, "$ref"), "a body is a $ref to an object component"); }
        return named[t].obj;
    }

    // The operation node, method of the path at routes' end: its handler,
    // security, path parameters in the template's order, and body.
    fn load_op(node: json::Node&, optr: const u8[:], method: const u8[:], shared: json::Node?, sptr: const u8[:],
               default_sec: json::Node?, schemes: json::Node?) {
        let route = routes[routes.len - 1];
        json::each(node) { k =>
            guard is_one_of(k.key, OPERATION_KEYS) else { fail(ptr1(optr, k.key), "not supported on an operation"); }
        };
        let id, idok = json::as_string(json::member(node, "operationId"));
        guard idok else { fail(optr, "an operation needs an operationId, its handler's name"); }
        let handler = local_name(id, ptr1(optr, "operationId"), []);
        for o in ops {
            guard o.handler != handler else { fail(ptr1(optr, "operationId"), str("another operation's handler is ", handler)); }
        }
        let sec = json::member(node, "security");
        let scheme = if sec { scheme_of(sec, ptr1(optr, "security"), schemes) } else { scheme_of(default_sec, "#/security", schemes) };
        let own = json::member(node, "parameters");
        let pptr = ptr1(optr, "parameters");
        // Each parameter is checked; the operation's override the path's.
        var i = 0;
        if shared { json::each(shared) { p => check_param(p, ptr1(sptr, str(i)), route.first_seg, route.nsegs); i++; }; }
        i = 0;
        if own { json::each(own) { p => check_param(p, ptr1(pptr, str(i)), route.first_seg, route.nsegs); i++; }; }
        let first = params.len;
        for s in segs[route.first_seg..route.first_seg + route.nsegs] {
            if !s.param { continue; }
            let in_own, at_own = find_name(own, s.text);
            let in_shared, at_shared = find_name(shared, s.text);
            var p = in_own;
            if !in_own { p .= in_shared; }
            guard p else { fail(optr, str("no parameter declares {", s.text, "}")); }
            let cptr = if in_own { ptr1(pptr, str(at_own)) } else { ptr1(sptr, str(at_shared)) };
            let pp = param_of(p, cptr, s.text, P_PATH);
            for q in params[first..] {
                guard q.local != pp.local else { fail(cptr, str("two parameters make the name ", pp.local)); }
            }
            params.push(pp);
        }
        let count = params.len - first;
        // The query, header, and cookie parameters: the path item's, then
        // the operation's own, which override one of the same name and place.
        let first_q = params.len;
        add_params(shared, sptr, own);
        add_params(own, pptr, null);
        var params_type: const u8[:] = strs[..0];
        if params.len > first_q {
            let at = strs.len;
            format_pascal(strs, id);
            strs.append("Params");
            params_type = strs[at..];
            type_name(params_type, ptr1(optr, "operationId"));
            // Each name the struct and its from_request declare, once.
            var names: (const u8[:])[>..] = [];
            for q in params[first_q..] {
                let n = strs.len;
                format(strs, q.local, " has_", q.local, " ");
                if q.int || q.boolean { format(strs, q.local, "_s"); }
                each_split(strs[n..], ' ') { if it.len > 0 { names.push(it); } };
            }
            for a, k in names {
                for b in names[k + 1..] {
                    guard a != b else { fail(ptr1(optr, "parameters"), str("two parameters make the name ", a)); }
                }
            }
        }
        let rb = json::member(node, "requestBody");
        let body = if rb { body_of(rb, ptr1(optr, "requestBody")) } else { -1 };
        ops.push(Op { method: method, handler: handler, scheme: scheme, body: body, first: first, count: count,
                      first_q: first_q, count_q: params.len - first_q, params_type: params_type });
    }

    // Each path's template, segments, and operations, checked against the
    // subset; and the Allow its operations make.
    fn load_paths(paths: json::Node&, default_sec: json::Node?, schemes: json::Node?) {
        json::each(paths) { item =>
            let template = item.key;
            let iptr = ptr1("#/paths", template);
            guard template.len > 0 && template[0] == '/' else { fail(iptr, "a path must start with '/'"); }
            let first_seg = segs.len;
            var is_static = true;
            var start = 1;
            loop {
                var end = start;
                while end < template.len && template[end] != '/' { end++; }
                let s = template[start..end];
                if s.len > 0 && s[0] == '{' {
                    let name = s[1..s.len - 1];
                    guard s.len > 2 && s[s.len - 1] == '}' && is_plain(name) && find(name, "{") < 0 && find(name, "}") < 0 else {
                        fail(iptr, "a parameter takes a whole segment, as {name}");
                    }
                    for q in segs[first_seg..] {
                        guard !(q.param && q.text == name) else { fail(iptr, str("{", name, "} is repeated")); }
                    }
                    segs.push(Seg { text: name, param: true });
                    is_static = false;
                } else {
                    guard is_plain(s) && find(s, "%") < 0 && find(s, "{") < 0 && find(s, "}") < 0 else {
                        fail(iptr, "a segment with '%', '{', '}', '\"', '\\' or a control character isn't supported");
                    }
                    segs.push(Seg { text: s, param: false });
                }
                if end == template.len { break; }
                start = end + 1;
            }
            let nsegs = segs.len - first_seg;
            for r in routes {
                if r.nsegs != nsegs { continue; }
                var same = true;
                for k in nsegs {
                    let a = segs[r.first_seg + k];
                    let b = segs[first_seg + k];
                    if a.param != b.param || !a.param && a.text != b.text { same = false; }
                }
                guard !same else { fail(iptr, str("matches the same requests as ", r.template)); }
            }
            json::each(item) { k =>
                guard is_one_of(k.key, METHODS) || is_one_of(k.key, PATH_ITEM_KEYS) else {
                    fail(ptr1(iptr, k.key), "not supported on a path item");
                }
            };
            routes.push(Route { template: template, first_seg: first_seg, nsegs: nsegs, first_op: ops.len,
                                is_static: is_static });
            let shared = json::member(item, "parameters");
            // The methods in the item's order, loaded outside the block that
            // finds them, which the checker otherwise can't settle.
            var order: i64[..8] = [];
            json::each(item) { m =>
                let i = method_index(m.key);
                if i >= 0 { order.push(i); }
            };
            for i in order {
                let m = json::member(item, METHODS[i]);
                guard m else { continue; }
                load_op(m, ptr1(iptr, METHODS[i]), HTTP_METHODS[i], shared, ptr1(iptr, "parameters"), default_sec, schemes);
            }
            let r .= routes[routes.len - 1];
            r.nops = ops.len - r.first_op;
            guard r.nops > 0 else { fail(iptr, "a path needs an operation"); }
            // Allow, as http::on builds it: each method once, in the
            // document's order, with HEAD after GET.
            let at = strs.len;
            for o in ops[r.first_op..] {
                for mth in [o.method, if o.method == "GET" { "HEAD" } else { "" }] {
                    if mth.len == 0 { continue; }
                    var seen = false;
                    each_split(strs[at..], ',') { if trim(it) == mth { seen = true; } };
                    if seen { continue; }
                    if strs.len > at { strs.append(", "); }
                    strs.append(mth);
                }
            }
            r.allow = strs[at..];
        };
    }

    let root, err = json::parse(text, doc, decoded);
    guard root else { return str(err); }
    let version, vok = json::as_string(json::member(root, "openapi"));
    guard vok && version.len >= 3 && version[..3] == "3.1" else { fail("#/openapi", "must be 3.1.x"); }
    let schemas = json::member(json::member(root, "components"), "schemas");
    guard schemas else { fail("#/components/schemas", "missing"); }
    json::each(schemas) { s => named.push(Named { name: s.key, node: s }); };

    // Each component that is an object or an enum is a type of its own,
    // named as the component, in the document's order.
    for &n in named {
        let ptr = ptr1("#/components/schemas", n.name);
        let t, ok = json::as_string(json::member(n.node, "type"));
        if ok && t == "object" && !json::member(n.node, "$ref") {
            type_name(n.name, ptr);
            check_keys(n.node, ptr, OBJECT_KEYWORDS, "an object");
            n.obj = add_obj(n.name, ptr, n.node);
        } else if ok && t == "string" && json::member(n.node, "enum") {
            type_name(n.name, ptr);
            check_keys(n.node, ptr, STRING_KEYWORDS, "a string");
            for k in ["minLength", "maxLength", "format"] {
                if json::member(n.node, k) { fail(ptr1(ptr, k), "not supported beside enum"); }
            }
            let values = json::member(n.node, "enum");
            guard values else { continue; }
            n.en = add_enum(n.name, ptr, values);
        }
    }
    // Any other component is checked where a $ref reads it, and once here.
    for n in named {
        if n.obj < 0 && n.en < 0 {
            let ty = type_of(n.node, ptr1("#/components/schemas", n.name), n.name, "", false);
            if ty.kind == K_ARR {
                let items = json::member(n.node, "items");
                guard items else { fail(ptr1("#/components/schemas", n.name), "an array needs items"); }
            }
        }
    }
    // objs grows as properties declare objects inline.
    var i = 0;
    while i < objs.len { load_obj(i); i++; }
    check_cycles();
    let paths = json::member(root, "paths");
    if paths {
        match paths.val { Obj o => {}, _ => fail("#/paths", "must be an object") }
        load_paths(paths, json::member(root, "security"), json::member(json::member(root, "components"), "securitySchemes"));
    }

    emit(out, ns, if routes.len > 0 { handlers } else { "" }, source, objs, enums, fields, variants);
    if routes.len > 0 { emit_router(out, ns, handlers, routes, segs, ops, params, objs); }
    return "";
}
