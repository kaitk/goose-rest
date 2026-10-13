// The generator: reads an OpenAPI 3.1 document and writes Goose source with a
// struct, a reader, and a writer for each schema under components.schemas.
// load() checks the whole document against the subset and lays the schemas
// out in flat tables; emit() writes the source from the tables. The subset
// and the code it becomes are in docs/generator.md.
namespace gen;

import std;
import json;
import .emit;

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
// fields[first..first + count]. pushed: an array holds it, so it gets a
// push_ function (docs/goose-findings.md, "A block can't push a value whose
// call grows a parameter's array").
struct Obj {
    name: const u8[:],
    ptr: const u8[:],
    node: json::Node&,
    closed: bool = false,
    first: i64 = 0,
    count: i64 = 0,
    pushed: bool = false,
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

// Reads the document and writes the source to out. Returns "" or the first
// error, as "<JSON pointer>: <message>".
fn generate(text: const u8[:], ns: const u8[:], source: const u8[:], out: u8[>..]&) -> u8[] {
    var doc: json::Node[>..] = [];
    var decoded: u8[>..] = [];
    var strs: u8[>..] = [];              // the names and pointers the tables point into
    var named: Named[>..] = [];
    var objs: Obj[>..] = [];
    var enums: Enum[>..] = [];
    var fields: Field[>..] = [];
    var variants: (const u8[:])[>..] = [];

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
                if item.kind == K_OBJ { objs[item.ref].pushed = true; }
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

    emit(out, ns, source, objs, enums, fields, variants);
    return "";
}
