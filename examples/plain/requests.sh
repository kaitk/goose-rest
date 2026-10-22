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
req POST /v1/projects -H "$auth" -H 'Content-Type: text/plain' -d 'name=x'
# Bodies past the read buffer, gathered before the route reads them.
big=$(printf '{"name": "big"%20000s}' '')
req POST /v1/projects -H "$auth" -H "$json" -d "$big"
req POST /v1/projects -H "$auth" -H "$json" -H 'Transfer-Encoding: chunked' -d "$big"
req GET '/v1/projects?q=go'
req GET /v1/projects/2
# A logo within its route's 4 MB, and past it; a project body past its 1 MB,
# which plod::body refuses, under the server's 4 MB.
printf '%3000000s' '' >"$out/logo"
printf '%5000000s' '' >"$out/huge-logo"
printf '{"name": "big"%2000000s}' '' >"$out/big-project.json"
req PUT /v1/projects/2/logo -H "$auth" --data-binary @"$out/logo"
req PUT /v1/projects/2/logo -H "$auth" --data-binary @"$out/huge-logo"
req PUT /v1/projects/9/logo -H "$auth" --data-binary @"$out/logo"
req POST /v1/projects -H "$auth" -H "$json" --data-binary @"$out/big-project.json"
req GET /v1/projects/x
req DELETE /v1/projects/1 -H "$auth"
req GET /v1/projects/1
req PUT /v1/projects
req GET /v1/nope
req GET /nope
req GET /health -H 'Origin: https://evil.example'
req OPTIONS /v1/projects -H 'Origin: https://app.example' -H 'Access-Control-Request-Method: POST'
# A project from a form, which curl's -d sends as
# application/x-www-form-urlencoded, and a form past the read buffer.
req POST /v1/projects -H "$auth" -d 'name=wild+goose%21&name=ignored'
req POST /v1/projects -H "$auth" -d 'name='
req POST /v1/projects -H "$auth" -d 'title=x'
req POST /v1/projects -H "$auth" -d 'name=%zz'
req POST /v1/projects -H "$auth" -d "$(printf 'pad=%20000s&name=long' '' | tr ' ' x)"
