#!/usr/bin/env bash
# lib/checks.sh — individual compatibility check functions
#
# Requires: bash-test-libs/bash/colors.sh, output.sh, results.sh sourced first.
# Also requires: detect_distro() called so PKG_MGR and DISTRO_NAME are set.

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
    active=$(systemctl is-active  "$svc" 2>/dev/null || echo "unknown")
    enabled=$(systemctl is-enabled "$svc" 2>/dev/null || echo "unknown")

    if   [[ "$active" == "active"   ]]; then
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
        perms=$(stat -c '%a %U:%G' "$path" 2>/dev/null \
             || stat -f '%p %Su:%Sg' "$path" 2>/dev/null \
             || echo "?")
        result_pass "Exists: $path  (${size} bytes, perms=${perms})"
    elif [[ -d "$path" ]]; then
        result_warn "Path is a directory, not a file: $path"
    else
        result_fail "Not found: $path"
    fi
}
