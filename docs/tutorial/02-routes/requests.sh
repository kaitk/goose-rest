# The requests scripts/test-examples.sh sends to this program, in order.
req GET /health
req GET /v1/projects
req GET '/v1/projects?q=g&limit=1'
req GET '/v1/projects?archived=true'
req GET '/v1/projects?archived=yes'
req GET '/v1/projects?limit=ten'
req GET /v1/projects/2
req GET /v1/projects/9
req GET /v1/projects/two
req GET /v1/me
req GET /v1/me -H 'X-User: ada'
req GET /v1/me -H 'X-User: ada' -H 'Cookie: theme=dark'
req DELETE /v1/projects/2
req GET /v1/nope
req GET /nope
