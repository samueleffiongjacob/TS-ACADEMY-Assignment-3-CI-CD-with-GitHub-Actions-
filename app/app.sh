#!/usr/bin/env bash
# =============================================================================
# app.sh - Small Bash application used for the CI/CD pipeline.
#
# Commands:
#   app.sh system-info            show system information
#   app.sh check-host <host>      resolve a host and show its address
#   app.sh check-port <host> <port>  test TCP connectivity to host:port
#   app.sh help                   show usage
#
# Exit codes:
#   0 = success
#   1 = check failed (host does not resolve, port closed)
#   2 = invalid command or input
# =============================================================================

set -u

readonly EXIT_OK=0
readonly EXIT_FAIL=1
readonly EXIT_USAGE=2

usage() {
    cat <<'USAGE'
Usage: app.sh <command> [arguments]

Commands:
  system-info               Show system information
  check-host <host>         Resolve a hostname or IP address
  check-port <host> <port>  Check TCP connectivity (port 1-65535)
  help                      Show this help message

Exit codes: 0 = success, 1 = check failed, 2 = invalid input
USAGE
}

# die_usage MESSAGE : print the error and exit with code 2
die_usage() {
    echo "Error: $1" >&2
    echo "Run 'app.sh help' for usage." >&2
    exit "$EXIT_USAGE"
}

# ---- Validation helpers -----------------------------------------------------

is_valid_ipv4() {
    local ip="$1" octet
    [[ "$ip" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]] || return 1
    local IFS=.
    for octet in $ip; do
        (( 10#$octet <= 255 )) || return 1
    done
    return 0
}

is_valid_host() {
    local host="$1"
    (( ${#host} >= 1 && ${#host} <= 253 )) || return 1
    if [[ "$host" =~ ^[0-9.]+$ ]]; then
        is_valid_ipv4 "$host"; return
    fi
    if [[ "$host" == *:* ]]; then
        [[ "$host" =~ ^[0-9A-Fa-f:]+$ ]]; return
    fi
    [[ "$host" =~ ^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$ ]]
}

# The port must be digits only (no "abc", no "-1") and between 1 and 65535.
is_valid_port() {
    [[ "$1" =~ ^[0-9]{1,5}$ ]] && (( 10#$1 >= 1 && 10#$1 <= 65535 ))
}

# ---- Commands ---------------------------------------------------------------

cmd_system_info() {
    local os="Linux"
    if [[ -r /etc/os-release ]]; then
        os="$( . /etc/os-release; echo "${PRETTY_NAME:-${NAME:-Linux}}" )"
    fi
    echo "=== System Information ==="
    echo "Hostname         : $(uname -n)"
    echo "Current user     : $(id -un 2>/dev/null || echo unknown)"
    echo "Date/time        : $(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo "Operating system : ${os}"
    echo "Kernel           : $(uname -sr)"
    echo "Architecture     : $(uname -m)"
    echo "CPU cores        : $(nproc 2>/dev/null || echo '?')"
    if [[ -r /proc/uptime ]]; then
        echo "Uptime           : $(awk '{printf "%d minutes", $1/60}' /proc/uptime)"
    fi
    if [[ -r /proc/meminfo ]]; then
        echo "Memory total     : $(awk '/^MemTotal/ {printf "%d MB", $2/1024}' /proc/meminfo)"
    fi
}

cmd_check_host() {
    [[ $# -ge 1 ]] || die_usage "check-host requires a host"
    [[ $# -eq 1 ]] || die_usage "check-host takes exactly one host"
    local host="$1" resolved

    is_valid_host "$host" || die_usage "invalid host: '$host'"

    resolved="$(getent ahosts "$host" 2>/dev/null | awk 'NR==1 {print $1}')"
    if [[ -z "$resolved" ]]; then
        echo "Host '$host' could not be resolved" >&2
        return "$EXIT_FAIL"
    fi
    echo "Host '$host' resolves to $resolved"
}

cmd_check_port() {
    [[ $# -ge 1 ]] || die_usage "check-port requires a host and a port"
    [[ $# -ge 2 ]] || die_usage "check-port requires a port"
    [[ $# -eq 2 ]] || die_usage "check-port takes exactly two arguments"
    local host="$1" port="$2"

    is_valid_host "$host" || die_usage "invalid host: '$host'"
    is_valid_port "$port" || die_usage "port must be an integer from 1 to 65535 (got '$port')"

    # Bash opens TCP connections through /dev/tcp/<host>/<port>. Host and port
    # are passed as arguments so they can never be interpreted as shell code.
    if timeout 3 bash -c 'exec 3<>"/dev/tcp/$1/$2"' _ "$host" "$port" 2>/dev/null; then
        echo "Port $port on $host is open"
    else
        echo "Port $port on $host is closed or unreachable" >&2
        return "$EXIT_FAIL"
    fi
}

# ---- Entry point ------------------------------------------------------------

main() {
    if [[ $# -eq 0 ]]; then
        usage >&2
        exit "$EXIT_USAGE"
    fi
    local command="$1"
    shift
    case "$command" in
        help|-h|--help) usage ;;
        system-info)
            [[ $# -eq 0 ]] || die_usage "system-info takes no arguments"
            cmd_system_info
            ;;
        check-host) cmd_check_host "$@" ;;
        check-port) cmd_check_port "$@" ;;
        *) die_usage "unknown command: '$command'" ;;
    esac
}

main "$@"
exit $?
