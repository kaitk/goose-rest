// error: rest needs the package tls
// A program that imports rest.tls must declare goose-tls in its root file.
import std;
import http from "github.com/kaitk/goose-http@5701a0d83a2f6e381bc13b69d80ae0a33d42daef";
import rest from "../../";
import rest.tls;

fn main() {}
