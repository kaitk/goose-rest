# The requests scripts/test-examples.sh sends to this program, in order.
# ada is a member of organization 1, and grace of organization 2.
req GET /health
req GET /settings
req GET /settings -H 'Authorization: Bearer ada'
req GET /organization/projects -H 'Authorization: Bearer nobody' -H 'X-Organization: 1'
req GET /organization/projects -H 'Authorization: Bearer ada'
req GET /organization/projects -H 'Authorization: Bearer ada' -H 'X-Organization: 2'
req GET /organization/projects -H 'Authorization: Bearer ada' -H 'X-Organization: x'
req POST /organization/projects -H 'Authorization: Bearer ada' -H 'X-Organization: 1' -d name=goose
req POST /organization/projects -H 'Authorization: Bearer ada' -H 'X-Organization: 1' -d name=
req POST /organization/projects -H 'Authorization: Bearer grace' -H 'X-Organization: 2' -d name=gander
req GET /organization/projects -H 'Authorization: Bearer ada' -H 'X-Organization: 1'
req GET /organization/teams -H 'Authorization: Bearer grace' -H 'X-Organization: 2'
req DELETE /organization/teams -H 'Authorization: Bearer grace' -H 'X-Organization: 2'
req GET /organization/members -H 'Authorization: Bearer grace' -H 'X-Organization: 2'
