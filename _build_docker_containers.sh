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

# Native Swift variant
docker build -f Dockerfile.devcontainer-swift -t "yolo_devcontainer:swift" .

# Build SwiftBridge variant
# SwiftBridge - access hosting OS commands (over TCP) from inside docker container
REPO="registry.getsven.com/swiftbridge-client-nio:release"
docker pull "$REPO"
docker cp $(docker create --rm "$REPO"):/usr/local/bin/SwiftBridgeClientNIO ./swiftbridge-client
docker build -f Dockerfile.devcontainer-swiftbridge -t "yolo_devcontainer:swiftbridge" .
rm ./swiftbridge-client

echo "Success. _build_docker_containers.sh completed."
