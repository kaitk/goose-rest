# The requests scripts/test-examples.sh sends to this program, in order.
# ada is a member of organization 1, and grace of organization 2.
req GET /health
req GET /settings
req GET /settings -H 'Authorization: Bearer ada'
req GET /organizations/1/projects -H 'Authorization: Bearer nobody'
req GET /organizations/2/projects -H 'Authorization: Bearer ada'
req GET /organizations/x/projects -H 'Authorization: Bearer ada'
req POST /organizations/1/projects -H 'Authorization: Bearer ada' -d name=goose
req POST /organizations/1/projects -H 'Authorization: Bearer ada' -d name=
req POST /organizations/2/projects -H 'Authorization: Bearer grace' -d name=gander
req GET /organizations/1/projects -H 'Authorization: Bearer ada'
req GET /organizations/2/teams -H 'Authorization: Bearer grace'
req DELETE /organizations/2/teams -H 'Authorization: Bearer grace'
req GET /organizations/2/members -H 'Authorization: Bearer grace'
