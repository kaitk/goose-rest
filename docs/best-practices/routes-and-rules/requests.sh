# The requests scripts/test-examples.sh sends to this program, in order.
req GET /health
req POST /projects -d name=goose
req POST /projects -d other=goose
req POST /projects -d name=
req POST /projects -d name=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
req POST /projects/1/archive
req POST /projects/1/archive
req POST /projects/9/archive
req POST /projects/x/archive
