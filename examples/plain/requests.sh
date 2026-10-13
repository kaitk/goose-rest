# The requests scripts/test-examples.sh sends to this example, in order.
json='Content-Type: application/json'
auth='Authorization: Bearer secret'
req GET /health
req GET /v1/projects
req POST /v1/projects -H "$json" -d '{"name": "goose"}'
req POST /v1/projects -H "$auth" -H "$json" -d '{"name": "goose"}'
req POST /v1/projects -H "$auth" -H "$json" -d '{"name": "gander"}'
req POST /v1/projects -H "$auth" -H "$json" -d '{"name": ""}'
req POST /v1/projects -H "Authorization: Bearer wrong" -H "$json" -d '{"name": "x"}'
req POST /v1/projects -H "$auth" -d 'name=x'
# Bodies past the read buffer, gathered before the route reads them.
big=$(printf '{"name": "big"%20000s}' '')
req POST /v1/projects -H "$auth" -H "$json" -d "$big"
req POST /v1/projects -H "$auth" -H "$json" -H 'Transfer-Encoding: chunked' -d "$big"
req GET '/v1/projects?q=go'
req GET /v1/projects/2
req GET /v1/projects/x
req DELETE /v1/projects/1 -H "$auth"
req GET /v1/projects/1
req PUT /v1/projects
req GET /v1/nope
req GET /nope
req GET /health -H 'Origin: https://evil.example'
req OPTIONS /v1/projects -H 'Origin: https://app.example' -H 'Access-Control-Request-Method: POST'
