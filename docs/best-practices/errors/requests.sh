# The requests scripts/test-examples.sh sends to this program, in order.
req GET /health
req GET /projects/1
req GET /projects/3
req GET /projects/x
req DELETE /projects/1
req DELETE /projects/3 -H 'X-Role: admin'
req DELETE /projects/2 -H 'X-Role: admin'
req DELETE /projects/1 -H 'X-Role: admin'
req PUT /projects/1
