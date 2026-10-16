# The requests scripts/test-examples.sh sends to this program, in order.
#
# long sends a request as req does, for an answer too long to print: its
# status, its Content-Length or Transfer-Encoding, its lines, and its first
# and last.
long() {
    method=$1
    path=$2
    shift 2
    : >"$out/body"
    code=$(curl -s -D "$out/head" -o "$out/body" -w '%{http_code}' -X "$method" "$@" \
        "http://127.0.0.1:$port$path") || true
    framing=$(tr -d '\r' <"$out/head" | grep -i -e '^content-length:' -e '^transfer-encoding:' | tr 'A-Z' 'a-z')
    echo "$method $path $code $framing lines=$(wc -l <"$out/body" | tr -d ' ')" \
        "first=$(head -n 1 "$out/body") last=$(tail -n 1 "$out/body")"
}
req GET /health
# 2,000 tasks, in pieces of 500 rows: chunked, since the length isn't known.
long GET /v1/projects/1/tasks.csv
req GET /v1/projects/2/tasks.csv
req GET /v1/projects/9/tasks.csv
# A client that reads 20 KB a second: the same rows, as it takes them.
long GET /v1/projects/1/tasks.csv --limit-rate 20K
# A file: 220 KB, and its second line as a range.
long GET /v1/projects/1/files/plans.txt
req GET /v1/projects/1/files/plans.txt -r 11-20
req GET /v1/projects/1/files/plans.txt -r 300000-
etag=$(curl -s -o /dev/null -D - "http://127.0.0.1:$port/v1/projects/1/files/plans.txt" | tr -d '\r' |
    sed -n 's/^[Ee][Tt]ag: //p')
req GET /v1/projects/1/files/plans.txt -H "If-None-Match: $etag"
req GET /v1/projects/1/files/missing.txt
req GET '/v1/projects/1/files/a%5Cb'
# Three progress events, 100 ms apart, then the end.
req GET '/v1/projects/2/progress?n=3' -N
req GET '/v1/projects/2/progress?n=0'
# A client that goes between events, after a quarter of a second, from a
# stream with no end: the worker goes on.
curl -s -N -m 0.25 -o /dev/null "http://127.0.0.1:$port/v1/projects/1/progress" || true
req GET /health
