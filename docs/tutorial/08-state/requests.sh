# The requests scripts/test-examples.sh sends to this program, in order.
req GET /me -H 'X-User: ada'
req GET /me -H 'X-User: grace'
req GET /me -H 'X-User: mallory'
req GET /me
