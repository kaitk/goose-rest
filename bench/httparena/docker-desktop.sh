# Appended to HttpArena's scripts/lib/stats.sh by bench/httparena.sh when
# Docker is Docker Desktop. Its containers' cgroups are in the Docker VM's
# cgroup namespace, not WSL's, so cpu.stat is read from a helper container in
# the host cgroup namespace, before and after the load runs.

_cgroup_cpu_path() {
    local id
    id=$(docker inspect -f '{{.Id}}' "$1" 2>/dev/null) || return 1
    [ -n "$id" ] || return 1
    printf '/sys/fs/cgroup/docker/%s/cpu.stat' "$id"
}

_cgroup_cpu_usec() {
    docker run --rm --privileged --cgroupns host busybox:1.37.0 \
        awk '/^usage_usec/ { print $2; exit }' "$1" 2>/dev/null
}
