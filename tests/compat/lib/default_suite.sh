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

    # Cron (name differs between distros — crond on RHEL/SLES, cron on Debian/Ubuntu)
    local cron_svc=""
    if systemctl cat crond.service &>/dev/null; then
        cron_svc="crond"
    elif systemctl cat cron.service &>/dev/null; then
        cron_svc="cron"
    fi
    if [[ -n "$cron_svc" ]]; then
        check_service "$cron_svc"
    else
        emit ""
        result_warn "No cron service found (checked crond, cron)"
    fi

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
