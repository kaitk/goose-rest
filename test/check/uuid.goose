// plod::is_uuid, format uuid's check.
import std;
import http from "github.com/kaitk/goose-http@v0.5.9";
import plod from "../../";

fn main() {
    assert(plod::is_uuid("123e4567-e89b-12d3-a456-426614174000"));
    assert(plod::is_uuid("123E4567-E89B-12D3-A456-426614174000"));
    assert(!plod::is_uuid("123e4567e89b12d3a456426614174000"));
    assert(!plod::is_uuid("123e4567-e89b-12d3-a456-42661417400g"));
    assert(!plod::is_uuid("{123e4567-e89b-12d3-a456-426614174000}"));
    print("plod::is_uuid: ok");
}
