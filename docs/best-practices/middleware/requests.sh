# The requests scripts/test-examples.sh sends to this program, in order.
# ada is a member of organization 1, and grace of organization 2.
req GET /health
req GET /health -H 'Origin: https://evil.example'
req GET /settings
req GET /settings -H 'Authorization: Bearer nobody'
req GET /settings -H 'Authorization: Bearer grace'
req GET /organizations/1/projects -H 'Authorization: Bearer ada'
req GET /organizations/2/projects -H 'Authorization: Bearer ada'
req GET /organizations/2/projects -H 'Authorization: Bearer grace' -H 'Origin: https://app.example'
req GET /organizations -H 'Authorization: Bearer grace'
