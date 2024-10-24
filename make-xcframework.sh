#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd -P)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

PROJECT_BUILD_DIR="${PROJECT_BUILD_DIR:-"${PROJECT_ROOT}/build"}"
XCODEBUILD_BUILD_DIR="$PROJECT_BUILD_DIR/xcodebuild"
XCODEBUILD_DERIVED_DATA_PATH="$XCODEBUILD_BUILD_DIR/DerivedData"

PACKAGE_NAME=$1
if [ -z "$PACKAGE_NAME" ]; then
    echo "No package name provided. Using the first scheme found in the Package.swift."
    PACKAGE_NAME=$(xcodebuild -list -workspace . | awk 'schemes && NF>0 { print $1; exit } /Schemes:$/ { schemes = 1 }')
    echo "Using: $PACKAGE_NAME"
fi

backup_package_swift() {
    cp Package.swift Package.swift.bak
}

restore_package_swift() {
    mv Package.swift.bak Package.swift
}

modify_package_swift() {
    sed -i '' 's/type: .static,//g' Package.swift
    sed -i '' 's/type: .dynamic,//g' Package.swift
    sed -i '' -e ':a' -e 'N' -e '$!ba' -e 's/\(library[^,]*name: [^,]*,\)/\1 type: .dynamic,/g' Package.swift
}

build_framework() {
    local sdk="$1"
    local destination="$2"
    local scheme="$3"

    local XCODEBUILD_ARCHIVE_PATH="./$scheme-$sdk.xcarchive"

    rm -rf "$XCODEBUILD_ARCHIVE_PATH"

    xcodebuild archive \
        -scheme $scheme \
        -archivePath $XCODEBUILD_ARCHIVE_PATH \
        -derivedDataPath "$XCODEBUILD_DERIVED_DATA_PATH" \
        -sdk "$sdk" \
        -destination "$destination" \
        -workspace . \
        BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
        INSTALL_PATH='Library/Frameworks' \
        OTHER_SWIFT_FLAGS=-no-verify-emitted-module-interface

    FRAMEWORK_MODULES_PATH="$XCODEBUILD_ARCHIVE_PATH/Products/Library/Frameworks/$scheme.framework/Modules"
    mkdir -p "$FRAMEWORK_MODULES_PATH"
    cp -r \
    "$XCODEBUILD_DERIVED_DATA_PATH/Build/Intermediates.noindex/ArchiveIntermediates/$scheme/BuildProductsPath/Release-$sdk/$scheme.swiftmodule" \
    "$FRAMEWORK_MODULES_PATH/$scheme.swiftmodule"
    # Delete private swiftinterface
    rm -f "$FRAMEWORK_MODULES_PATH/$scheme.swiftmodule/*.private.swiftinterface"
}

echo "Modifying Package.swift"
backup_package_swift
modify_package_swift

build_framework "iphonesimulator" "generic/platform=iOS Simulator" "$PACKAGE_NAME"
build_framework "iphoneos" "generic/platform=iOS" "$PACKAGE_NAME"

echo "Builds completed successfully."

rm -rf "$PACKAGE_NAME.xcframework"
xcodebuild -create-xcframework -framework $PACKAGE_NAME-iphonesimulator.xcarchive/Products/Library/Frameworks/$PACKAGE_NAME.framework -framework $PACKAGE_NAME-iphoneos.xcarchive/Products/Library/Frameworks/$PACKAGE_NAME.framework -output $PACKAGE_NAME.xcframework

cp -r $PACKAGE_NAME-iphonesimulator.xcarchive/dSYMs $PACKAGE_NAME.xcframework/ios-arm64_x86_64-simulator
cp -r $PACKAGE_NAME-iphoneos.xcarchive/dSYMs $PACKAGE_NAME.xcframework/ios-arm64

zip -r "$PACKAGE_NAME.xcframework.zip" "$PACKAGE_NAME.xcframework"

echo "Restoring Package.swift"
restore_package_swift
