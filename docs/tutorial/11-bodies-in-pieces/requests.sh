# The requests scripts/test-examples.sh sends to this program, in order.
# bytes N prints N bytes.
bytes() { head -c "$1" /dev/zero | tr '\0' 'a'; }
# files lists the attachments directory, once no .part file is left in it, or
# after two seconds.
files() {
    tries=0
    while ls "$ATTACHMENTS" | grep -q '\.part$' && [ "$tries" -lt 20 ]; do
        tries=$((tries + 1))
        sleep 0.1
    done
    echo "files: $(ls "$ATTACHMENTS" | tr '\n' ' ')"
}
req GET /health
# Small: the body comes whole with its head, as one piece.
printf 'Hello, attachments.' | req POST /v1/projects/1/attachments --data-binary @-
# 2 MB, past the 8 KB read buffer: written a piece at a time.
bytes 2000000 | req POST /v1/projects/1/attachments --data-binary @-
# Refused before the body is read.
bytes 1000 | req POST /v1/projects/9/attachments --data-binary @-
# Project 2 takes 64 KB: 413 from the Content-Length, before the body is sent.
bytes 100000 | req POST /v1/projects/2/attachments --data-binary @-
# Chunked, with no length: counted as it comes, 413 once past 64 KB.
bytes 100000 | req POST /v1/projects/2/attachments -H 'Transfer-Encoding: chunked' --data-binary @-
# A client that gives up after a second, a tenth of the way: no answer, and
# its .part file is deleted.
bytes 1000000 | req POST /v1/projects/1/attachments --limit-rate 100K -m 1 --data-binary @-
files
# A multipart form of a note and a file.
bytes 30000 >"$out/plans.txt"
req POST /v1/projects/1/attachments/form -F 'note=Floor plans' -F "file=@$out/plans.txt"
req POST /v1/projects/1/attachments/form --data-binary 'note=Floor plans'
req POST /v1/projects/1/attachments/form -H 'Content-Type: multipart/form-data; boundary=xyz' --data-binary 'no parts'
files
