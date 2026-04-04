#!/usr/bin/env bash
#

set -o errexit
set -o nounset
set -o pipefail
if [[ "${TRACE-0}" == "1" ]]; then
    set -o xtrace
fi

cd "$(dirname "$0")"

# Build base image first (no Swift)
docker build -f Dockerfile.devcontainer -t "yolo_devcontainer" .

if [ "$(hostname)" == "realm13.local" ]; then
    # Native Swift variant
    docker build -f Dockerfile.devcontainer-swift -t "yolo_devcontainer:swift" .

    #
    # Build SwiftBridge variant
    # SwiftBridge - access hosting OS commands (over TCP) from inside docker container
    #
    REPO="reimpl"
    REPO_CLIENT="$REPO/swiftbridge-client-nio:release"
    docker pull "$REPO_CLIENT"
    docker cp $(docker create --rm "$REPO_CLIENT"):/usr/local/bin/SwiftBridgeClientNIO ./swiftbridge-client
    docker build -f Dockerfile.devcontainer-swiftbridge -t "yolo_devcontainer:swiftbridge" .
    rm ./swiftbridge-client

    # #
    # mkdir -p ~/.local/bin
    # REPO_SERVER="$REPO/swiftbridge-server:release"
    # docker pull "$REPO_SERVER"
    # docker cp $(docker create --rm "$REPO_SERVER"):/usr/local/bin/SwiftBridgeServer ~/.local/bin/swiftbridge-server
fi

echo "Success. _build_docker_containers.sh completed."
