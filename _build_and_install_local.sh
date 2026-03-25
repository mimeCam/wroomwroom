#!/usr/bin/env bash
#

set -o errexit
set -o nounset
set -o pipefail
if [[ "${TRACE-0}" == "1" ]]; then
    set -o xtrace
fi

cd "$(dirname "$0")"

rebuild() {
    EXECUTABLE_NAME="$1"
    WORKING_NAME="$1"

    if [[ -n "${2:-}" ]]; then
        NEW_NAME="$2"
    fi

    swift build \
        -Xswiftc -strict-concurrency=minimal \
        -c release --product $EXECUTABLE_NAME

    if [[ -n "${NEW_NAME:-}" ]]; then
        mv .build/release/$EXECUTABLE_NAME .build/release/$NEW_NAME
        WORKING_NAME="$NEW_NAME"
    fi

    echo "Killing old service"
    set +o errexit && set +o nounset && set +o pipefail
    killall $WORKING_NAME;
    mv ~/.local/bin/$WORKING_NAME ~/.local/bin/$WORKING_NAME-old;
    set -o errexit && set -o nounset && set -o pipefail

    mv .build/release/$WORKING_NAME ~/.local/bin/
    echo "Moved ${WORKING_NAME} to ~/.local/bin/"
}

main() {
    if [ $# -lt 1 ] || [ $# -gt 2 ]; then
        echo "Usage: $0 <target> [new_name]"
        exit 1
    fi

    if [ $# -eq 2 ]; then
        rebuild "$1" "$2"
    else
        rebuild "$1"
    fi
}

if [ "${1:-}" == "clean" ]; then
    # Apple's swift builder often uses stale build artefacts
    # and fails to recognize changes to src code
    rm -rf .build/release
    rm -rf .build/arm64-apple-macosx/release
    # rm -rf .build/index-build
fi

mkdir -p $HOME/.local/bin
cp scripts/yolo/* $HOME/.local/bin/

main "openloop"
main "runner" "openloop-runner"
main "api" "openloop-api"

echo "Success. _build_and_install_local.sh completed."
