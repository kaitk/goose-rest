// error: rest needs the package tls
// A program that imports rest.tls must declare goose-tls in its root file.
import std;
import http from "github.com/kaitk/goose-http@e128cb39d82c0fa45280452b1c434a55384e14d7";
import rest from "../../";
import rest.tls;

fn main() {}
