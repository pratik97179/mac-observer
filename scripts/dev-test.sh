#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$root"

if [ -d /Library/Developer/CommandLineTools ]; then
  export DEVELOPER_DIR=/Library/Developer/CommandLineTools
fi

sdk26="/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk"
if [ -d "$sdk26" ]; then
  export SDKROOT="$sdk26"
else
  export SDKROOT=$(xcrun --sdk macosx --show-sdk-path)
fi

testing_plugins="/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing"
extra=""
if [ -d "$testing_plugins" ]; then
  extra="-Xswiftc -plugin-path -Xswiftc $testing_plugins"
fi

echo "DEVELOPER_DIR=${DEVELOPER_DIR:-}"
echo "SDKROOT=$SDKROOT"
# shellcheck disable=SC2086
swift test $extra "$@"
