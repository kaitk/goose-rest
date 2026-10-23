// error: plod needs the package tls
// A program that imports plod.tls must declare goose-tls in its root file.
import std;
import http from "github.com/kaitk/goose-http@v0.5.6";
import plod from "../../";
import plod.tls;

fn main() {}
