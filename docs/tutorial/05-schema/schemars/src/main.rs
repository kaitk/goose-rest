// docs/tutorial/06-schema-languages.md: a field with format: ascii, written with
// schemars 1.x. cargo run prints the JSON Schema, which holds
// "format": "ascii" and "maxLength": 7.
use schemars::{schema_for, JsonSchema};

#[derive(JsonSchema)]
struct Project {
    #[schemars(length(max = 7), extend("format" = "ascii"))]
    color: String,
}

fn main() {
    println!("{}", serde_json::to_string_pretty(&schema_for!(Project)).unwrap());
}
