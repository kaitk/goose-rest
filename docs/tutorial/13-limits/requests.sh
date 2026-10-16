# The requests scripts/test-examples.sh sends to this program, in order.
req GET /health
req GET /v1/projects/1/summary
# The database takes 500 ms, past the route's 200: 504. It goes on with the
# job, and its answer is dropped.
req GET '/v1/projects/1/summary?ms=500'
# The database is still busy: these two jobs wait in the box's two slots,
# and their clients give up (curl prints 000). The database skips them later.
req GET /v1/projects/1/summary -m 0.05
req GET /v1/projects/1/summary -m 0.05
# The box is full: 503 at once.
req GET /v1/projects/1/summary
sleep 1
req GET /v1/gone
# A report runs for half a second: 202 at once, and the client asks.
req POST /v1/projects/1/reports
req GET /v1/reports/1
sleep 1
req GET /v1/reports/1
req GET /v1/reports/9
