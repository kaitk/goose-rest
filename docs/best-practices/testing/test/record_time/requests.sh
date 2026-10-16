# A member records time: a project, then entries on it through the writer
# lane, one of them refused. Each line is a request to the running server.
req GET /health
req POST /projects -d name=goose
req POST /entries -d 'project=1&started=1767250800&stopped=1767254400'
req POST /entries -d 'project=1&started=1767254400&stopped=1767258000'
req POST /entries -d 'project=1&started=1767258000&stopped=1767254400'
req POST /projects/1/archive
