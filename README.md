# distro-compat-checker

![CI](https://github.com/sawaiwalatrupti/distro-compat-checker/actions/workflows/ci.yml/badge.svg)

A Bash script that validates whether packages, binaries, kernel modules, systemd services, and config files are present and working correctly on the current Linux distribution.

Useful for cross-distro validation — verifying that a component behaves identically on RHEL, SLES, Ubuntu, and Debian.

---

## What it checks

| Check type | What it validates |
|---|---|
| **Package** | Installed status + version (supports `rpm` and `dpkg`) |
| **Binary** | Present in `$PATH`, version string |
| **Kernel module** | Available via `modinfo`, loaded via `lsmod` |
| **Systemd service** | `active`/`inactive` status, `enabled`/`disabled` |
| **Config file** | Exists, size, permissions |

Supports RHEL, CentOS, Rocky, AlmaLinux, SLES, openSUSE, Ubuntu, Debian.

---

## Usage

```bash
chmod +x check_compat.sh

# Run the built-in default suite (core tools, SSH, network, compilers)
./check_compat.sh --all

# Check a specific package
./check_compat.sh -p openssh-server

# Check a kernel module
./check_compat.sh -m kvm

# Check a systemd service
./check_compat.sh -s sshd

# Check a binary in PATH
./check_compat.sh -b python3

# Check a config file exists
./check_compat.sh -c /etc/ssh/sshd_config

# Combine multiple checks
./check_compat.sh -p qemu-kvm -m kvm -s libvirtd

# Save results to a file
./check_compat.sh --all -o /tmp/compat_report.txt
```

---

## Sample output

```
════════════════════════════════════════════════════════════
  Linux Distro Compatibility Report
════════════════════════════════════════════════════════════
  Host       : rhel9-test-01
  Generated  : 2025-06-01 15:00:12
  Distro     : Red Hat Enterprise Linux 9.3  (id=rhel)
  Kernel     : 5.14.0-362.8.1.el9_3.x86_64
  Arch       : x86_64
  Pkg manager: rpm
────────────────────────────────────────────────────────────

  Package: openssh-server
  [PASS] Installed: openssh-server  version=8.7p1-34.el9

  Binary: gcc
  [PASS] Found: /usr/bin/gcc
  [INFO] Version string: gcc (GCC) 11.4.1 20230605

  Kernel module: kvm
  [PASS] Module loaded: kvm

  Systemd service: sshd
  [PASS] Service active: sshd  (enabled=enabled)

  Config file: /etc/ssh/sshd_config
  [PASS] Exists: /etc/ssh/sshd_config  (3426 bytes, perms=600 root:root)

────────────────────────────────────────────────────────────
  Results:  PASS: 5   WARN: 0   FAIL: 0
════════════════════════════════════════════════════════════
```

---

## Options

| Flag | Description |
|---|---|
| `-p NAME` | Check a package by name |
| `-b NAME` | Check a binary in PATH |
| `-m NAME` | Check a kernel module |
| `-s NAME` | Check a systemd service |
| `-c PATH` | Check a config file exists |
| `-o FILE` | Save plain-text report to FILE |
| `--all` | Run the built-in default check suite |
| `-h` | Show help |

---

## Exit codes

| Code | Meaning |
|---|---|
| `0` | All checks passed (or only warnings) |
| `1` | One or more checks failed |

This makes it suitable for use in CI pipelines — run as a pre-test sanity check and fail the pipeline if the environment is misconfigured.

---

## Requirements

- Bash 4.0+
- `systemctl` (for service checks)
- `rpm` or `dpkg` (for package checks — auto-detected)
- `lsmod` and `modinfo` (for module checks)
- [testlib-core](https://github.com/sawaiwalatrupti/testlib-core) cloned as a sibling directory

```bash
git clone https://github.com/sawaiwalatrupti/testlib-core.git
git clone https://github.com/sawaiwalatrupti/distro-compat-checker.git
# both must be in the same parent directory
```

Tested on RHEL 9, SLES 15 SP5, Ubuntu 22.04, Ubuntu 24.04.
