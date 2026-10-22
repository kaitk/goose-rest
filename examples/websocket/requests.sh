# The requests scripts/test-examples.sh sends to this example, in order.
#
# ws sends a WebSocket's handshake and then frames, raw, with curl's
# telnet:// (as an upload, -T -, as examples/upgrade's requests.sh says why),
# and prints the status and the frames that came back, each byte that isn't
# a letter shown as a dot. The frames are masked with a key of zeros, so
# their payloads stay readable.
ws() {
    printf "$1" | curl -s -m 5 -T - "telnet://127.0.0.1:$port" >"$out/body" || true
    code=$(head -n 1 "$out/body" | cut -d ' ' -f 2)
    frames=$(sed '1,/^\r$/d' "$out/body" | LC_ALL=C tr -c 'a-z' '.')
    echo "WS /ws $code $frames"
}
open='GET /ws HTTP/1.1\r\nHost: x\r\nConnection: Upgrade\r\nUpgrade: websocket\r\nSec-WebSocket-Version: 13\r\nSec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n\r\n'
hello='\201\205\000\000\000\000hello'
close='\210\202\000\000\000\000\003\350'
req GET /health
# Without the handshake's fields, the route refuses.
req GET /ws
# "hello" back, then the Close answered with its code, 1000.
ws "${open}${hello}${close}"
