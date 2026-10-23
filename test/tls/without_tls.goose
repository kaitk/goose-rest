// error: plod needs the package tls
// A program that imports plod.tls must declare goose-tls in its root file.
import std;
import http from "github.com/kaitk/goose-http@ebb4238728179e82140550af50e5bab1a7e0dab2";
import plod from "../../";
import plod.tls;

fn main() {}
