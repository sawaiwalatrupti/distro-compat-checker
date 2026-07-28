#!/usr/bin/env bash
# check_compat.sh — Linux distro compatibility checker
#
# Checks whether a given package/binary/service behaves consistently
# on the current distro. Validates:
#   - Package presence and version
#   - Binary existence in PATH
#   - Kernel module presence and load status
#   - Systemd service status
#   - Key configuration file presence
#
# Designed for cross-distro validation work (RHEL, SLES, Ubuntu, Debian).
#
# Usage:
#   ./check_compat.sh                          # run all built-in checks
#   ./check_compat.sh -p openssh-server        # check a specific package
#   ./check_compat.sh -m ext4                  # check a kernel module
#   ./check_compat.sh -s sshd                  # check a systemd service
#   ./check_compat.sh -b ssh                   # check a binary in PATH
#   ./check_compat.sh -c /etc/ssh/sshd_config  # check a config file exists
#   ./check_compat.sh --all                    # run default suite of checks
#   ./check_compat.sh -o report.txt            # save results to file

set -euo pipefail

# ── colours ───────────────────────────────────────────────────────────────────
if [ -t 1 ]; then
    RED='\033[0;31m'; YELLOW='\033[0;33m'; GREEN='\033[0;32m'
    CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
else
    RED=''; YELLOW=''; GREEN=''; CYAN=''; BOLD=''; RESET=''
fi

# ── state ─────────────────────────────────────────────────────────────────────
PASS=0; FAIL=0; WARN=0
REPORT_LINES=()
OUTPUT_FILE=""
RUN_ALL=0

# Targets from CLI
PKG_CHECKS=(); BIN_CHECKS=(); MOD_CHECKS=(); SVC_CHECKS=(); CFG_CHECKS=()

# ── helpers ───────────────────────────────────────────────────────────────────
usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Options:
  -p, --package NAME      Check if a package is installed and show version
  -b, --binary NAME       Check if a binary exists in PATH
  -m, --module NAME       Check if a kernel module is available/loaded
  -s, --service NAME      Check systemd service status
  -c, --config PATH       Check if a configuration file exists
  -o, --output FILE       Write plain-text report to FILE
  --all                   Run the built-in default check suite
  -h, --help              Show this help

Examples:
  $0 --all                           Run default suite
  $0 -p qemu-kvm -s libvirtd         Check KVM stack
  $0 -m kvm -m vfio                  Check virtualisation modules
  $0 -p gcc -b gcc -o gcc_check.txt
EOF
    exit 0
}

emit() {
    echo -e "$1"
    REPORT_LINES+=("$1")
}

result_pass() { emit "  ${GREEN}[PASS]${RESET} $1"; PASS=$((PASS+1)); }
result_fail() { emit "  ${RED}[FAIL]${RESET} $1"; FAIL=$((FAIL+1)); }
result_warn() { emit "  ${YELLOW}[WARN]${RESET} $1"; WARN=$((WARN+1)); }
result_info() { emit "  ${CYAN}[INFO]${RESET} $1"; }

# ── distro detection ──────────────────────────────────────────────────────────
detect_distro() {
    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        source /etc/os-release
        DISTRO_ID="${ID:-unknown}"
        DISTRO_NAME="${NAME:-unknown}"
        DISTRO_VERSION="${VERSION_ID:-unknown}"
    else
        DISTRO_ID="unknown"
        DISTRO_NAME="Unknown"
        DISTRO_VERSION="unknown"
    fi

    case "$DISTRO_ID" in
        rhel|centos|fedora|rocky|almalinux) PKG_MGR="rpm" ;;
        sles|opensuse*) PKG_MGR="rpm" ;;
        ubuntu|debian) PKG_MGR="dpkg" ;;
        *) PKG_MGR="unknown" ;;
    esac
}

# ── individual check functions ────────────────────────────────────────────────
check_package() {
    local pkg="$1"
    emit ""
    emit "${BOLD}  Package: $pkg${RESET}"

    case "$PKG_MGR" in
        rpm)
            if rpm -q "$pkg" &>/dev/null; then
                local ver
                ver=$(rpm -q --queryformat '%{VERSION}-%{RELEASE}' "$pkg" 2>/dev/null)
                result_pass "Installed: $pkg  version=$ver"
            else
                result_fail "Not installed: $pkg (distro: $DISTRO_NAME)"
            fi
            ;;
        dpkg)
            if dpkg -s "$pkg" &>/dev/null && \
               [[ "$(dpkg -s "$pkg" 2>/dev/null | grep '^Status:' || true)" == *"installed"* ]]; then
                local ver
                ver=$(dpkg -s "$pkg" 2>/dev/null | awk '/^Version:/{print $2}')
                result_pass "Installed: $pkg  version=$ver"
            else
                result_fail "Not installed: $pkg (distro: $DISTRO_NAME)"
            fi
            ;;
        *)
            result_warn "Cannot check package '$pkg': unknown package manager on $DISTRO_NAME"
            ;;
    esac
}

check_binary() {
    local bin="$1"
    emit ""
    emit "${BOLD}  Binary: $bin${RESET}"

    if command -v "$bin" &>/dev/null; then
        local path ver
        path=$(command -v "$bin")
        ver=$("$bin" --version 2>&1 | head -1 || true)
        result_pass "Found: $path"
        result_info "Version string: $ver"
    else
        result_fail "Not found in PATH: $bin"
    fi
}

check_module() {
    local mod="$1"
    emit ""
    emit "${BOLD}  Kernel module: $mod${RESET}"

    if lsmod 2>/dev/null | grep -qw "^${mod}"; then
        result_pass "Module loaded: $mod"
    elif modinfo "$mod" &>/dev/null; then
        result_warn "Module available but not loaded: $mod"
        local path
        path=$(modinfo -n "$mod" 2>/dev/null || true)
        result_info "Module path: $path"
    else
        result_fail "Module not found: $mod"
    fi
}

check_service() {
    local svc="$1"
    emit ""
    emit "${BOLD}  Systemd service: $svc${RESET}"

    if ! command -v systemctl &>/dev/null; then
        result_warn "systemctl not available — skipping service check for $svc"
        return
    fi

    if ! systemctl list-unit-files "${svc}.service" &>/dev/null; then
        result_fail "Service unit not found: ${svc}.service"
        return
    fi

    local active enabled
    active=$(systemctl is-active "$svc" 2>/dev/null || echo "unknown")
    enabled=$(systemctl is-enabled "$svc" 2>/dev/null || echo "unknown")

    if [[ "$active" == "active" ]]; then
        result_pass "Service active: $svc  (enabled=$enabled)"
    elif [[ "$active" == "inactive" ]]; then
        result_warn "Service inactive: $svc  (enabled=$enabled)"
    else
        result_fail "Service status: $svc  active=$active  enabled=$enabled"
    fi
}

check_config() {
    local path="$1"
    emit ""
    emit "${BOLD}  Config file: $path${RESET}"

    if [[ -f "$path" ]]; then
        local size perms
        size=$(wc -c < "$path")
        perms=$(stat -c '%a %U:%G' "$path" 2>/dev/null || stat -f '%p %Su:%Sg' "$path" 2>/dev/null || echo "?")
        result_pass "Exists: $path  (${size} bytes, perms=${perms})"
    elif [[ -d "$path" ]]; then
        result_warn "Path is a directory, not a file: $path"
    else
        result_fail "Not found: $path"
    fi
}

# ── default check suite ───────────────────────────────────────────────────────
run_default_suite() {
    emit ""
    emit "${BOLD}  Running default compatibility check suite...${RESET}"

    # Core system tools
    for bin in bash python3 perl awk sed grep tar gzip; do
        check_binary "$bin"
    done

    # SSH
    check_service "sshd"
    check_config  "/etc/ssh/sshd_config"

    # Logging
    check_service "rsyslog"
    check_config  "/etc/rsyslog.conf"

    # Cron
    check_service "crond" 2>/dev/null || check_service "cron" 2>/dev/null || true

    # Network
    check_service "NetworkManager"
    for mod in ipv6 iptable_filter nf_conntrack; do
        check_module "$mod"
    done

    # Compilers (common validation target)
    for bin in gcc g++ make; do
        check_binary "$bin"
    done
}

# ── argument parsing ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        -p|--package) PKG_CHECKS+=("$2"); shift 2 ;;
        -b|--binary)  BIN_CHECKS+=("$2"); shift 2 ;;
        -m|--module)  MOD_CHECKS+=("$2"); shift 2 ;;
        -s|--service) SVC_CHECKS+=("$2"); shift 2 ;;
        -c|--config)  CFG_CHECKS+=("$2"); shift 2 ;;
        -o|--output)  OUTPUT_FILE="$2";   shift 2 ;;
        --all)        RUN_ALL=1;          shift   ;;
        -h|--help)    usage ;;
        *) echo "Unknown option: $1"; usage ;;
    esac
done

# If no checks specified at all, default to --all
if [[ ${#PKG_CHECKS[@]} -eq 0 && ${#BIN_CHECKS[@]} -eq 0 && \
      ${#MOD_CHECKS[@]} -eq 0 && ${#SVC_CHECKS[@]} -eq 0 && \
      ${#CFG_CHECKS[@]} -eq 0 && "$RUN_ALL" -eq 0 ]]; then
    RUN_ALL=1
fi

# ── main ──────────────────────────────────────────────────────────────────────
detect_distro

NOW=$(date '+%Y-%m-%d %H:%M:%S')
HOSTNAME=$(hostname)
KERNEL=$(uname -r)

emit ""
emit "${BOLD}════════════════════════════════════════════════════════════${RESET}"
emit "${BOLD}  Linux Distro Compatibility Report${RESET}"
emit "${BOLD}════════════════════════════════════════════════════════════${RESET}"
emit "  Host       : $HOSTNAME"
emit "  Generated  : $NOW"
emit "  Distro     : $DISTRO_NAME $DISTRO_VERSION  (id=$DISTRO_ID)"
emit "  Kernel     : $KERNEL"
emit "  Arch       : $(uname -m)"
emit "  Pkg manager: $PKG_MGR"
emit "${BOLD}────────────────────────────────────────────────────────────${RESET}"

[[ "$RUN_ALL"             -eq 1 ]] && run_default_suite
for p in "${PKG_CHECKS[@]}";  do check_package "$p"; done
for b in "${BIN_CHECKS[@]}";  do check_binary  "$b"; done
for m in "${MOD_CHECKS[@]}";  do check_module  "$m"; done
for s in "${SVC_CHECKS[@]}";  do check_service "$s"; done
for c in "${CFG_CHECKS[@]}";  do check_config  "$c"; done

emit ""
emit "${BOLD}────────────────────────────────────────────────────────────${RESET}"
emit "${BOLD}  Results:  ${GREEN}PASS: $PASS${RESET}   ${YELLOW}WARN: $WARN${RESET}   ${RED}FAIL: $FAIL${RESET}"
emit "${BOLD}════════════════════════════════════════════════════════════${RESET}"
emit ""

# ── save to file if requested ─────────────────────────────────────────────────
if [[ -n "$OUTPUT_FILE" ]]; then
    printf '%s\n' "${REPORT_LINES[@]}" | sed 's/\x1b\[[0-9;]*m//g' > "$OUTPUT_FILE"
    echo -e "${CYAN}[INFO]${RESET}  Report saved to: $OUTPUT_FILE"
fi

# Exit non-zero if any checks failed
[[ "$FAIL" -gt 0 ]] && exit 1 || exit 0
