#!/usr/bin/env bash
# check_compat.sh — Linux distro compatibility checker (entry point)
#
# Usage:
#   ./check_compat.sh                          # run built-in default suite
#   ./check_compat.sh -p openssh-server        # check a specific package
#   ./check_compat.sh -m ext4                  # check a kernel module
#   ./check_compat.sh -s sshd                  # check a systemd service
#   ./check_compat.sh -b ssh                   # check a binary in PATH
#   ./check_compat.sh -c /etc/ssh/sshd_config  # check a config file exists
#   ./check_compat.sh --all                    # run default suite
#   ./check_compat.sh -o report.txt            # save results to file

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"
SHARED_LIB="$SCRIPT_DIR/../../../testlib-core/bash"

# ── load shared library ───────────────────────────────────────────────────────
if [[ ! -d "$SHARED_LIB" ]]; then
    echo "ERROR: testlib-core not found at: $SHARED_LIB" >&2
    echo "       Clone it: git clone https://github.com/sawaiwalatrupti/testlib-core.git" >&2
    exit 1
fi

# shellcheck source=../../../testlib-core/bash/colors.sh
source "$SHARED_LIB/colors.sh"
# shellcheck source=../../../testlib-core/bash/output.sh
source "$SHARED_LIB/output.sh"
# shellcheck source=../../../testlib-core/bash/results.sh
source "$SHARED_LIB/results.sh"
# shellcheck source=../../../testlib-core/bash/distro.sh
source "$SHARED_LIB/distro.sh"

# ── load local check functions ────────────────────────────────────────────────
# shellcheck source=lib/checks.sh
source "$LIB_DIR/checks.sh"
# shellcheck source=lib/default_suite.sh
source "$LIB_DIR/default_suite.sh"

# ── state ─────────────────────────────────────────────────────────────────────
REPORT_LINES=()
PASS=0; FAIL=0; WARN=0
OUTPUT_FILE=""
RUN_ALL=0

PKG_CHECKS=(); BIN_CHECKS=(); MOD_CHECKS=(); SVC_CHECKS=(); CFG_CHECKS=()

# ── usage ─────────────────────────────────────────────────────────────────────
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

# Default to --all if nothing specified
if [[ ${#PKG_CHECKS[@]} -eq 0 && ${#BIN_CHECKS[@]} -eq 0 &&
      ${#MOD_CHECKS[@]} -eq 0 && ${#SVC_CHECKS[@]} -eq 0 &&
      ${#CFG_CHECKS[@]} -eq 0 && "$RUN_ALL" -eq 0 ]]; then
    RUN_ALL=1
fi

# ── main ──────────────────────────────────────────────────────────────────────
detect_distro

NOW=$(date '+%Y-%m-%d %H:%M:%S')

emit ""
emit "${BOLD}════════════════════════════════════════════════════════════${RESET}"
emit "${BOLD}  Linux Distro Compatibility Report${RESET}"
emit "${BOLD}════════════════════════════════════════════════════════════${RESET}"
emit "  Host       : $(hostname)"
emit "  Generated  : $NOW"
emit "  Distro     : $DISTRO_NAME $DISTRO_VERSION  (id=$DISTRO_ID)"
emit "  Kernel     : $(uname -r)"
emit "  Arch       : $(uname -m)"
emit "  Pkg manager: $PKG_MGR"
emit "${BOLD}────────────────────────────────────────────────────────────${RESET}"

[[ "$RUN_ALL" -eq 1 ]] && run_default_suite

for p in "${PKG_CHECKS[@]}"; do check_package "$p"; done
for b in "${BIN_CHECKS[@]}"; do check_binary  "$b"; done
for m in "${MOD_CHECKS[@]}"; do check_module  "$m"; done
for s in "${SVC_CHECKS[@]}"; do check_service "$s"; done
for c in "${CFG_CHECKS[@]}"; do check_config  "$c"; done

emit ""
emit "${BOLD}────────────────────────────────────────────────────────────${RESET}"
emit "${BOLD}  Results:  ${GREEN}PASS: $PASS${RESET}   ${YELLOW}WARN: $WARN${RESET}   ${RED}FAIL: $FAIL${RESET}"
emit "${BOLD}════════════════════════════════════════════════════════════${RESET}"
emit ""

[[ -n "$OUTPUT_FILE" ]] && save_report "$OUTPUT_FILE"

[[ "$FAIL" -gt 0 ]] && exit 1 || exit 0
