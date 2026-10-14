# The requests scripts/test-examples.sh sends to this example, in order.
json='Content-Type: application/json'
auth='Authorization: Bearer secret'
req GET /health
req GET /v1/projects
req POST /v1/projects -H "$json" -d '{"name": "goose"}'
req POST /v1/projects -H "$auth" -H "$json" -d '{"name": "goose"}'
req POST /v1/projects -H "$auth" -H "$json" -d '{"name": "gander"}'
req POST /v1/projects -H "$auth" -H "$json" -d '{"name": "goose", "color": "x"}'
req POST /v1/projects -H "$auth" -d '{"name": "goose"}'
req GET '/v1/projects?q=go'
req GET '/v1/projects?limit=1'
req GET '/v1/projects?limit=0'
req GET /v1/projects/2
req GET /v1/projects/0
req DELETE /v1/projects/1 -H "$auth"
req GET /v1/projects/1
req PUT /v1/projects
req GET /nope
# Bodies past 1 MB, within createProject's x-body-limit of 2 MB and past it.
printf '{"name": "big"%1500000s}' '' >"$out/big.json"
printf '{"name": "huge"%3000000s}' '' >"$out/huge.json"
req POST /v1/projects -H "$auth" -H "$json" --data-binary @"$out/big.json"
req POST /v1/projects -H "$auth" -H "$json" --data-binary @"$out/huge.json"
