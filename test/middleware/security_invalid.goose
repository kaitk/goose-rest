import std;
import http from "github.com/kaitk/goose-http@v0.4.3";
import rest from "../../";

fn main() {
    var options = rest::security_html();
    options.content_security_policy = "default-src 'self'\r\nX-Injected: yes";
    print("security headers reject CRLF during setup");
    rest::prepare_security_headers(options);
}
