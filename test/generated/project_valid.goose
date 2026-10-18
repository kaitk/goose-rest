// Valid Projects read and written back by the generated reader and writer.
import std;
import json;
import http from "github.com/kaitk/goose-http@v0.3.7";
import rest from "../../";
import expect from "../";
import expect.gen.api_gen;
import common;

fn main() {
    project(minimal(""),
        """{"id":1,"name":"goose","status":"active","owner":{"id":7,"email":"ada@example.com"},"tags":[],"createdAt":"2026-10-13T18:28:00Z"}""");
    // Every field, keys in another order, an unknown key skipped, a string
    // with escapes, a repeated key whose last value wins, and nulls.
    project("""
        {"type": "x", "settings": {"channels": ["slack", "email"], "notify": true, "other": 1},
         "kind": "client", "ref": "123e4567-e89b-12d3-a456-426614174000", "dueOn": null,
         "createdAt": "2026-10-13T18:28:00+02:00", "scores": [1, 0.5, -2e-3], "tags": ["a", "b\"c", "ü"],
         "reviewers": [{"id": 2, "email": "b@c.de", "displayName": "Bee"}, {"id": 3, "email": "c@d.ef", "displayName": null}],
         "owner": {"displayName": "Ada", "email": "ada@example.com", "id": 7, "unknown": [1, {"a": 2}]},
         "public": false, "priority": -5, "budget": 0, "status": "in-review", "name": "first",
         "name": "goose é", "id": 42, "extra": {"x": [null]}}
        """,
        """{"id":42,"name":"goose é","status":"in-review","budget":0.0,"priority":-5,"public":false,"owner":{"id":7,"email":"ada@example.com","displayName":"Ada"},"reviewers":[{"id":2,"email":"b@c.de","displayName":"Bee"},{"id":3,"email":"c@d.ef","displayName":null}],"tags":["a","b\"c","ü"],"scores":[1.0,0.5,-0.002],"createdAt":"2026-10-13T18:28:00+02:00","dueOn":null,"ref":"123e4567-e89b-12d3-a456-426614174000","kind":"client","settings":{"notify":true,"channels":["slack","email"]},"type":"x"}""");
    // Only the optional field after the first one, and a settings of null.
    project(minimal(""", "settings": {"channels": []}, "dueOn": "2024-02-29" """),
        """{"id":1,"name":"goose","status":"active","owner":{"id":7,"email":"ada@example.com"},"tags":[],"createdAt":"2026-10-13T18:28:00Z","dueOn":"2024-02-29","settings":{"channels":[]}}""");
    project(minimal(""", "settings": null, "budget": 999999999.5 """),
        """{"id":1,"name":"goose","status":"active","budget":999999999.5,"owner":{"id":7,"email":"ada@example.com"},"tags":[],"createdAt":"2026-10-13T18:28:00Z","settings":null}""");
    project(minimal(""", "settings": {}, "tags": ["12345678901234567890"] """),
        """{"id":1,"name":"goose","status":"active","owner":{"id":7,"email":"ada@example.com"},"tags":["12345678901234567890"],"createdAt":"2026-10-13T18:28:00Z","settings":{}}""");
    print("valid Projects, read and written back: ok");
}
