#!/usr/bin/env bash
#
# This scripts installs openloop by building from source code.
# Use this if you plan to contibute to openloop.
#

set -o errexit
set -o nounset
set -o pipefail
if [[ "${TRACE-0}" == "1" ]]; then
    set -o xtrace
fi

cd "$(dirname "$0")"

verify_available() {
    local cmd=$1
    if ! command -v "$cmd" &> /dev/null; then
        echo "Error: $cmd is not installed or not in PATH"
        exit 1
    fi
}

verify_and_install_swift() {
    if command -v swift &> /dev/null; then
        return 0
    fi

    echo "Swift is not installed. Installing via swiftly..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        curl -O https://download.swift.org/swiftly/darwin/swiftly.pkg
        installer -pkg swiftly.pkg -target CurrentUserHomeDirectory
        ~/.swiftly/bin/swiftly init --quiet-shell-followup
        . "${SWIFTLY_HOME_DIR:-$HOME/.swiftly}/env.sh"
        hash -r
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        curl -O "https://download.swift.org/swiftly/linux/swiftly-$(uname -m).tar.gz"
        tar zxf "swiftly-$(uname -m).tar.gz"
        ./swiftly init --quiet-shell-followup
        . "${SWIFTLY_HOME_DIR:-$HOME/.local/share/swiftly}/env.sh"
        hash -r
    elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OSTYPE" == "win32" ]]; then
        winget install --id Microsoft.VisualStudio.2022.Community --exact --force --custom "--add Microsoft.VisualStudio.Component.Windows11SDK.22621 --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 --add Microsoft.VisualStudio.Component.VC.Tools.ARM64" --source winget
        winget install --id Swift.Toolchain -e --source winget
    else
        echo "Error: Unsupported OS: $OSTYPE. Visit https://www.swift.org/install/ for installation instructions."
        exit 1
    fi
}

# install_yq() {
#     if command -v yq &> /dev/null; then
#         return 0
#     fi

#     echo "Installing yq..."
#     if [[ "$OSTYPE" == "darwin"* ]]; then
#         if command -v brew &> /dev/null; then
#             brew install yq
#         else
#             echo "Error: Homebrew is required to install yq on macOS. yq is used to prepare markdown files for later use by opencode in  oc_docker. Ref: https://opencode.ai/docs/agents#markdown"
#             exit 1
#         fi
#     elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
#         local arch="amd64"
#         if [[ "$(uname -m)" == "aarch64" ]] || [[ "$(uname -m)" == "arm64" ]]; then
#             arch="arm64"
#         fi
#         local yq_url="https://github.com/mikefarah/yq/releases/latest/download/yq_linux_${arch}"
#         echo "Installing yq from $yq_url..."
#         if command -v wget &> /dev/null; then
#             sudo wget "$yq_url" -O /usr/local/bin/yq
#         elif command -v curl &> /dev/null; then
#             sudo curl -sL "$yq_url" -o /usr/local/bin/yq
#         else
#             echo "Error: wget or curl required to download yq"
#             exit 1
#         fi
#         sudo chmod +x /usr/local/bin/yq
#     else
#         echo "Error: Unsupported OS: $OSTYPE"
#         exit 1
#     fi
# }

# yq 4+ fails to work with frontmatter + body
# install_yq

verify_available docker
./_build_docker_containers.sh

verify_and_install_swift
./_build_and_install_local.sh
#
# rm -rf ~/.local/bin/Public
cp -r Sources/api/Public ~/.local/bin
pkill openloop-api || true
(cd ~/.local/bin && ./openloop-api serve --port 54321 > /dev/null 2>&1 &)


echo "Checking cc_docker:"
openloop_cc_docker "test-pirate-slang" "ahoy there" "speak like true Jack Sparrow ey" "plan"
echo "Checking oc_docker:"
openloop_oc_docker "test-pirate-slang" "howdy there" "speak like true Jack Sparrow ey" "plan"

echo ""
echo "SUCCESS. To add openloop to a project run 'openloop' in terminal from the project's folder . Control Plane available at http://localhost:54321/"

if [[ "$OSTYPE" == "darwin"* ]]; then
    open http://localhost:54321/ || true
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    xdg-open http://localhost:54321/ || true
fi

echo "U r doing God's work 🪽"
echo "Installation complete. Cha-ching!"
echo "Last part: Add ~/.local/bin to your PATH, then run 'w2' from the project's folder"
