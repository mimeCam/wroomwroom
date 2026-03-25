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

echo "TODO. This script should install pre-combiled binaries (without building from source like install_dev.sh does)."
exit 1
