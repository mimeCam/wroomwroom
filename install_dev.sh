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
docker build -f Dockerfile.devcontainer -t "yolo_devcontainer" .

verify_available swift
./_build_and_install_local.sh
#
# rm -rf ~/.local/bin/Public
cp -r Sources/api/Public ~/.local/bin
pkill openloop-api || true
(cd ~/.local/bin && ./openloop-api serve --port 54321 > /dev/null 2>&1 &)


echo "Checking oc_docker:"
openloop_oc_docker "test-pirate-slang" "howdy there" "speak like true Jack Sparrow ey" "plan"
echo "Checking cc_docker:"
openloop_cc_docker "test-pirate-slang" "ahoy there" "speak like true Jack Sparrow ey" "plan"

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
