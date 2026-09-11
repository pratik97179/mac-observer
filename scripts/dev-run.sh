#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$root"

if [ -d /Library/Developer/CommandLineTools ]; then
  export DEVELOPER_DIR=/Library/Developer/CommandLineTools
fi

# Swift 6.4 in Command Line Tools compiles SwiftUI and Darwin overlays
# against the 26.5 SDK. MacOSX.sdk currently points at 27.0, which
# requires SwiftUIMacros and _SwiftifyImport that this compiler does not
# provide. Collectors must use size-bounded Darwin APIs because the
# kernel on this Mac is still newer than that SDK.
sdk26="/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk"
if [ -d "$sdk26" ]; then
  export SDKROOT="$sdk26"
else
  export SDKROOT=$(xcrun --sdk macosx --show-sdk-path)
fi

echo "DEVELOPER_DIR=${DEVELOPER_DIR:-}"
echo "SDKROOT=$SDKROOT"
swift --version

swift build --product MacObserver
bin_dir=$(swift build --show-bin-path)
bin="$bin_dir/MacObserver"
app="$root/.build/MacObserver.app"

rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin" "$app/Contents/MacOS/MacObserver"
cp "$root/App/Bundle-Info.plist" "$app/Contents/Info.plist"

resource_bundle="$bin_dir/MacObserver_MacObserver.bundle"
if [ -d "$resource_bundle" ]; then
  cp -R "$resource_bundle" "$app/Contents/Resources/"
fi

echo "Launching $app"
exec open "$app"
