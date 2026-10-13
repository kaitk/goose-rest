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
