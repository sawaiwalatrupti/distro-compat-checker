#!/usr/bin/env bash
# lib/default_suite.sh — built-in default compatibility check suite
#
# Requires: checks.sh (and its dependencies) sourced first.

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

    # Cron (name differs between distros)
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
