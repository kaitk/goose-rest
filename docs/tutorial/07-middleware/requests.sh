# The requests scripts/test-examples.sh sends to this program, in order.
req GET /health
req GET /v1/projects
req GET /v1/projects -H 'X-Tenant: acme'
req POST /admin/reindex
req POST /admin/reindex -H 'Authorization: Bearer wrong'
req POST /admin/reindex -H 'Authorization: Bearer secret'
req GET /admin/reindex -H 'Authorization: Bearer secret'
req GET /v1/projects -H 'X-Tenant: acme' -H 'Origin: https://app.example'
req GET /health -H 'Origin: https://evil.example'
req OPTIONS /admin/reindex -H 'Origin: https://app.example' -H 'Access-Control-Request-Method: POST'
