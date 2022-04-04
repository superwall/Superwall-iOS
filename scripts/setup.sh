#!/bin/bash
# Copyright (c) Nest22.
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

echo 'Installing githooks...'
ln -s -f ../../scripts/pre-commit .git/hooks

echo 'Checking for SwiftLint...'
if which swiftlint >/dev/null; then
    echo 'Swiftlint already installed ✅'
else
    if which brew >/dev/null; then
      echo 'Installing SwiftLint...'
      brew install swiftlint
    else
      echo "
      Error: SwiftLint could not be installed!
      Download from https://github.com/realm/SwiftLint,
      or brew install swiftlint. Then run this script again.
      "
      exit 1
    fi
fi

echo 'Done!'
