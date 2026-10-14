# The requests scripts/test-examples.sh sends to this program, in order.
json='Content-Type: application/json'
auth='Authorization: Bearer secret'
req GET /health
req GET /v1/projects
req POST /v1/projects -H "$json" -d '{"name": "goose"}'
req POST /v1/projects -H 'Authorization: Bearer wrong' -H "$json" -d '{"name": "goose"}'
req POST /v1/projects -H "$auth" -H "$json" -d '{"name": "goose"}'
req POST /v1/projects -H "$auth" -H "$json" -d '{"name": "gander", "color": "grey"}'
# Bodies past the 8 KB read buffer: within createProject's x-body-limit of
# 16 KB, and past it.
printf '{"name": "big"%12000s}' '' >"$out/big.json"
printf '{"name": "huge"%20000s}' '' >"$out/huge.json"
req POST /v1/projects -H "$auth" -H "$json" --data-binary @"$out/big.json"
req POST /v1/projects -H "$auth" -H "$json" --data-binary @"$out/huge.json"
req GET '/v1/projects?limit=1'
req GET '/v1/projects?limit=0'
req GET '/v1/projects?q=bi'
req GET /v1/projects/2
req GET /v1/projects/0
req GET /v1/projects/7
req DELETE /v1/projects/1
# The hand-written scope: an upload within its 2 MB, one past the server's
# max_body, and one without a token.
printf '%1500000s' '' >"$out/upload"
printf '%3000000s' '' >"$out/huge-upload"
req PUT /uploads/logo.png -H "$auth" --data-binary @"$out/upload"
req PUT /uploads/logo.png -H "$auth" --data-binary @"$out/huge-upload"
req PUT /uploads/logo.png --data-binary @"$out/upload"
req GET /uploads/logo.png
req GET /nope
