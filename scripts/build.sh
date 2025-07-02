#!/bin/bash
# Copyright (c) Nest22.
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

set -e

# Navigate to project root
cd "$(dirname "$0")/.."

echo "🔨 Building SuperwallKit framework..."

# Generate Xcode project from project.yml
echo "📋 Generating Xcode project..."
if command -v xcodegen >/dev/null 2>&1; then
    xcodegen
else
    echo "❌ xcodegen not found. Please install it with: brew install xcodegen"
    exit 1
fi

mkdir -p .log

xcodebuild \
  -project SuperwallKit.xcodeproj \
  -scheme SuperwallKit \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination "platform=iOS Simulator,name=iPhone 16" \
  build > .log/build.log 2>&1

# Check if build failed
if [ $? -ne 0 ]; then
    echo "❌ Build failed! Here's the build log:"
    echo "========================================"
    cat .log/build.log
    echo "========================================"
    exit 1
fi


echo "✅ Build completed successfully!"
