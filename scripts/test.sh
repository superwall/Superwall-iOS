#!/bin/bash
# Copyright (c) Nest22.
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

set -e

# Navigate to project root
cd "$(dirname "$0")/.."

echo "🧪 Running SuperwallKit tests..."

mkdir -p .log

# Run tests for iOS Simulator using xcodebuild with live output
xcodebuild \
  -scheme SuperwallKit \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination "platform=iOS Simulator,name=iPhone 16" \
  test 2>&1 | tee .log/test.log

# Check if tests failed
if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo "❌ Tests failed! Here's the test log:"
    echo "========================================"
    cat .log/test.log
    echo "========================================"
    exit 1
fi

echo "✅ All tests passed successfully!"
