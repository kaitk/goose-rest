# The requests scripts/test-examples.sh sends to this example, in order.
#
# upgraded sends a request's bytes, and then the client's bytes, raw, with
# curl's telnet:// for up to the seconds given, and prints the status and
# what came back after the head, its lines joined with |.
upgraded() {
    printf "$2" | curl -s -m "$1" "telnet://127.0.0.1:$port" >"$out/body" || true
    code=$(head -n 1 "$out/body" | cut -d ' ' -f 2)
    echoed=$(tr -d '\r' <"$out/body" | sed '1,/^$/d' | paste -s -d '|' -)
    echo "UPGRADE /echo $code $echoed"
}
upgrade='GET /echo HTTP/1.1\r\nHost: x\r\nConnection: Upgrade\r\nUpgrade: echo\r\n\r\n'
req GET /health
# Without Upgrade: echo, the route refuses.
req GET /echo
# Echoed until "bye", then the server closes the connection.
upgraded 5 "${upgrade}hello\nbye\n"
# A client that goes first: the route gets CLOSED, which logs the bytes.
upgraded 1 "${upgrade}hello\n"
tries=0
until grep -q 'closed after' "$out/$name.log" || [ "$tries" -gt 20 ]; do
    tries=$((tries + 1))
    sleep 0.1
done
sed -n 's/^echo: //p' "$out/$name.log"
