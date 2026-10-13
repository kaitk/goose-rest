# The requests scripts/test-examples.sh sends to this example, in order. An
# export of 40 rows is about 600 bytes: ten replies' worth of 64 bytes, sent
# on as a chunked response.
req GET /health
req GET '/v1/report?org=3&from=1&to=10'
req GET '/v1/report?org=3&from=1'
req GET '/v1/report?org=3&from=5&to=1'
req GET '/v1/export?org=7&rows=3'
req GET '/v1/export?org=7&rows=40'
req GET '/v1/export?org=7&rows=x'
req GET /v1/nope
