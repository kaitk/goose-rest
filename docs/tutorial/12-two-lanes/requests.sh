# The requests scripts/test-examples.sh sends to this program, in order.
# Project 1's tasks are 196 bytes of JSON, which with the job's 20 bytes in
# front are four replies' worth of 64 bytes, sent on as a chunked response.
req GET /health
req GET /v1/projects/1/tasks
req GET /v1/projects/2/tasks
req POST '/v1/projects/1/members?user=3'
req POST '/v1/projects/2/members?user=3'
req POST '/v1/projects/1/members?user=3'
req POST '/v1/projects/9/members?user=3'
