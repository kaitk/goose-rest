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
# Two clients that go before their exports answer: the first while the
# database works on its job, so its answer is dropped, and the second before
# its job starts, so the database skips it. curl gives up, and prints 000.
req GET '/v1/export?org=7&rows=40&ms=1000' -m 0.2
req GET '/v1/export?org=7&rows=40' -m 0.2
req GET /v1/gone
