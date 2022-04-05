#!/bin/bash
# Copyright (c) Nest22.
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

if test -d "/opt/homebrew/bin/"; then
  PATH="/opt/homebrew/bin/:${PATH}"
  export PATH
fi

if which swiftlint >/dev/null; then
    swiftlint lint --config ../.swiftlint.yml
else
    echo "
    Error: SwiftLint not installed!
    Download from https://github.com/realm/SwiftLint,
    or brew install swiftlint.
    "
    exit 1
fi
