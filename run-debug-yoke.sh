#!/bin/bash
cd "$(dirname "$0")"
source ./script/setup.sh

./generate.sh --ignore-cmd-help --ignore-shell-parser --codesign-identity "yoke-codesign"

xcodebuild-pretty .debug-xcodebuild.log build \
    -scheme AeroSpace \
    -configuration Debug \
    -derivedDataPath .xcode-build

open .xcode-build/Build/Products/Debug/Yoke-Debug.app
