#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

SYSTEM_PACKAGES=(
    binutils
    unzip
    libc6-dev
    libcurl4-openssl-dev
    libpython3-dev
    libxml2-dev
    libncurses-dev
    libz3-dev
    pkg-config
    zlib1g-dev
)

if [ "$(id -u)" -eq 0 ] || [[ "$PWD" == /root/* ]]; then
    apt-get update

    gcc_version=$(gcc --version 2>/dev/null | head -1 | grep -oP '\d+' | head -1) || true
    if [[ -z "$gcc_version" ]]; then
        gcc_version=$(apt-cache search '^libgcc-[0-9]+-dev$' 2>/dev/null | grep -oP 'libgcc-\K\d+' | sort -n | tail -1)
    fi
    if [[ -z "$gcc_version" ]]; then
        echo "Error: Could not determine GCC version for libgcc/libstdc++ dev packages" >&2
        exit 1
    fi

    apt-get -y install "${SYSTEM_PACKAGES[@]}" "libgcc-${gcc_version}-dev" "libstdc++-${gcc_version}-dev"

    echo "Error: Running as root or under /root/ is not supported." >&2
    echo "Docker containers use a non-root 'node' (uid 1000) user that cannot write files owned by root, or traverse /root." >&2
    echo "Run as a different (non-root) user." >&2
    echo ""
    echo "To create new user with 'node' username (different is OK):"
    echo "useradd -m -s /bin/bash node"
    echo "usermod -aG docker node"
    echo "passwd node"
    echo "su - node"
    echo ""

    exit 1
fi

if [[ "$OSTYPE" != "linux-gnu"* ]]; then
    exit 0
fi

gcc_version=$(gcc --version 2>/dev/null | head -1 | grep -oP '\d+' | head -1) || true
if [[ -z "$gcc_version" ]]; then
    gcc_version=$(dpkg -l 'libgcc-*-dev' 2>/dev/null | grep '^ii' | grep -oP 'libgcc-\K\d+' | sort -n | tail -1) || true
fi

missing=()
for pkg in "${SYSTEM_PACKAGES[@]}"; do
    if ! dpkg -s "$pkg" &>/dev/null | grep -q 'Status: install ok installed'; then
        missing+=("$pkg")
    fi
done
if [[ -n "$gcc_version" ]]; then
    for pkg in "libgcc-${gcc_version}-dev" "libstdc++-${gcc_version}-dev"; do
        if ! dpkg -s "$pkg" &>/dev/null | grep -q 'Status: install ok installed'; then
            missing+=("$pkg")
        fi
    done
fi

if [[ ${#missing[@]} -gt 0 ]]; then
    echo "WARNING: The following packages are not installed: ${missing[*]}" >&2
    echo "Swift build may fail. Run install_dev.sh as root first to install them." >&2
fi

exit 0
