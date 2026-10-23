# The requests scripts/test-examples.sh sends to this example, in order.
#
# coded sends a request as req does, and prints its answer's Content-Encoding
# and Vary, the bytes that came, and, once curl decodes them, the body's
# size and checksum, which match the uncompressed answer's.
coded() {
    method=$1
    path=$2
    shift 2
    : >"$out/body"
    sent=$(curl -s --compressed -D "$out/head" -o "$out/body" -w '%{http_code} %{size_download}' -X "$method" "$@" \
        "http://127.0.0.1:$port$path") || true
    coding=$(tr -d '\r' <"$out/head" | sed -n 's/^[Cc]ontent-[Ee]ncoding: //p')
    vary=$(tr -d '\r' <"$out/head" | sed -n 's/^[Vv]ary: //p')
    echo "$method $path ${sent% *} encoding=${coding:-none} vary=${vary:-none} sent=${sent#* }" \
        "body=$(cksum <"$out/body" | tr -s ' ' | tr ' ' /)"
}
req GET /health
req GET /v1/events/7
req GET '/v1/events?limit=2'
req GET '/v1/events?limit=x'
req GET /v1/nope
coded GET '/v1/events?limit=100' -H 'Accept-Encoding: identity'
coded GET '/v1/events?limit=100' -H 'Accept-Encoding: gzip'
coded GET '/v1/events?limit=100' -H 'Accept-Encoding: deflate'
coded GET '/v1/events?limit=100' -H 'Accept-Encoding: deflate, gzip'
coded GET /v1/events/7 -H 'Accept-Encoding: gzip'
coded GET /v1/events/0 -H 'Accept-Encoding: gzip'
coded GET /nope -H 'Accept-Encoding: gzip'
# The export in pieces of 100 events, each compressed as it's sent: the same
# body in each coding.
coded GET '/v1/export?limit=1000' -H 'Accept-Encoding: identity'
coded GET '/v1/export?limit=1000' -H 'Accept-Encoding: gzip'
coded GET '/v1/export?limit=1000' -H 'Accept-Encoding: deflate'
coded GET '/v1/export?limit=0' -H 'Accept-Encoding: gzip'
# /archive's options: level 9, smaller than /v1's level 1; and gzip where
# zstd is offered, since the archive doesn't offer zstd. A listing of five,
# past the 256-byte minimum, is compressed under both.
coded GET '/archive/events?limit=100' -H 'Accept-Encoding: gzip'
coded GET '/archive/events?limit=100' -H 'Accept-Encoding: zstd, gzip'
coded GET '/archive/events?limit=5' -H 'Accept-Encoding: gzip'
coded GET '/v1/events?limit=5' -H 'Accept-Encoding: gzip'
coded GET /archive/events/7 -H 'Accept-Encoding: gzip'
