// ProjectCreate, whose fields are fixed-size: read and written back, its
// string lengths in code points, and each error.
import std;
import json;
import http from "github.com/kaitk/goose-http@v0.5.4";
import plod from "../../";
import expect from "../";
import expect.gen.api_gen;
import common;

fn main() {
    create("""{"name": "g"}""", """{"name":"g"}""");
    create("""{"status": "archived", "color": "#ff0000", "name": "goose"}""",
        """{"name":"goose","color":"#ff0000","status":"archived"}""");
    // 120 code points of two bytes each fill the 480-byte field halfway.
    var long: u8[>..] = [];
    long.append("""{"name": " """);
    long.pop();
    for i in 120 { long.append("é"); }
    long.append("\"}");
    var want: u8[>..] = [];
    want.append("""{"name":" """);
    want.pop();
    for i in 120 { want.append("é"); }
    want.append("\"}");
    create(long, want);
    long.clear();
    long.append("""{"name": " """);
    long.pop();
    for i in 121 { long.append("é"); }
    long.append("\"}");
    bad_create(long, "name: maxLength");
    bad_create("""{"name": ""}""", "name: minLength");
    bad_create("""{"name": "\ud800"}""", "name: not UTF-8");
    bad_create("""{"color": "#ff0000"}""", "name: required");
    bad_create("""{"name": "goose", "colour": "#ff0000"}""", "unknown member");
    bad_create("""{"name": "goose", "color": "#ff00000"}""", "color: maxLength");
    // Seven code points, eight bytes: format ascii refuses it before the
    // seven-byte field could overflow.
    bad_create("""{"name": "goose", "color": "#ff000é"}""", "color: format");
    bad_create("""{"name": "goose", "color": "😀"}""", "color: format");
    print("ProjectCreate: ok");
}
