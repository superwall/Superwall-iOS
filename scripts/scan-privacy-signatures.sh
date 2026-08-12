#!/bin/bash
# Copyright (c) Nest22.
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.
#
# Fails when a permission API name Apple's App Store Connect scanner reacts to is
# compiled into the framework binary.
#
# The SDK reaches these APIs through the Objective-C runtime with ROT13-encoded class
# and selector names, so a correct build contains none of them in plaintext. They come
# back in two ways, both of which this catches: a string literal (an un-mangled plist
# key) lands in __TEXT,__cstring, and an `@objc` member (a fake stand-in class) lands
# in __TEXT,__objc_methname. Unit tests can't see either — only the built binary can.
#
# Scans those two sections rather than running `strings` over the whole binary: Swift
# mangles internal symbol names using the source names, so a debug binary legitimately
# contains "trackingAuthorizationStatus" inside `TrackingManagerProxy`'s own symbols.
# Matching on that would fail forever with nothing to fix.

set -e

cd "$(dirname "$0")/.."

BINARY="$1"

if [ -z "$BINARY" ]; then
  echo "usage: $0 <path-to-framework-binary>"
  exit 2
fi

if [ ! -f "$BINARY" ]; then
  echo "❌ Not a file: $BINARY"
  exit 2
fi

# Add a name here when the SDK starts reaching a new permission API by runtime lookup.
#
# Entries are bare names, not full selectors: a leaked name can wear several suffixes
# — "requestRecordPermission:" from an `@objc` member, "requestRecordPermission()"
# from `withCheckedContinuation`'s `#function` default — and the bare form matches
# them all. An entry must never legitimately appear in the scanned sections, so a hit
# is always a real leak.
#
# Deliberately absent: `LocationPermissionDelegate`'s callback selectors
# (locationManagerDidChangeAuthorization:, locationManager:didChangeAuthorization:).
# CLLocationManager dispatches those by selector at runtime, so their metadata has to
# exist for the callbacks to arrive. See the note on that class.
#
# Also absent: names from the camera, photos, and notification handlers. Those call
# their frameworks directly rather than through mangled runtime lookups — e.g.
# `AVCaptureDevice.requestAccess(for:)` legitimately emits
# `requestAccessForMediaType:completionHandler:` — so their names in the binary are
# how the SDK works today, not a leak. If they ever join the proxy scheme, add them.
#
# Also absent, and unlike the above this one is a genuine `@objc` shim: `FakeASIdManager`
# (its class name, and its `sharedManager` selector). It survives where the four
# permission fakes were deleted because it is load-bearing — it's what makes
# `classType.sharedManager()` typecheck through AnyObject lookup — and `sharedManager`
# is a generic Cocoa selector shared by many classes, so it fingerprints nothing. The
# AdSupport names that would fingerprint (the class and property below) are mangled, and
# guarded here.
FORBIDDEN=(
  # Tracking — the one App Store Connect actively warns about.
  "NSUserTrackingUsageDescription"
  "ATTrackingManager"
  "requestTrackingAuthorization"
  "trackingAuthorizationStatus"
  # Microphone, location, and contacts — reached the same way, so hold them to the
  # same standard even though no scanner is known to flag them.
  "AVAudioSession"
  "recordPermission"
  "requestRecordPermission"
  "CLLocationManager"
  "requestWhenInUseAuthorization"
  "requestAlwaysAuthorization"
  "CNContactStore"
  "requestAccessForEntityType"
  # AdSupport (IDFA) — reached through the same runtime-lookup proxy, which mangles
  # both the class name and the `advertisingIdentifier` property.
  "ASIdentifierManager"
  "advertisingIdentifier"
)

echo "🔍 Scanning $(basename "$BINARY") for privacy API signatures..."

SECTIONS=$(
  {
    otool -v -s __TEXT __objc_methname "$BINARY" 2>/dev/null
    otool -v -s __TEXT __objc_classname "$BINARY" 2>/dev/null
    otool -v -s __TEXT __cstring "$BINARY" 2>/dev/null
  }
)

if [ -z "$SECTIONS" ]; then
  echo "❌ Could not read Objective-C metadata from $BINARY."
  exit 2
fi

FOUND=()
for name in "${FORBIDDEN[@]}"; do
  if grep -qF "$name" <<< "$SECTIONS"; then
    FOUND+=("$name")
  fi
done

if [ ${#FOUND[@]} -ne 0 ]; then
  echo "❌ Found permission API signatures in the compiled binary:"
  for name in "${FOUND[@]}"; do
    echo "     - $name"
  done
  echo ""
  echo "   These reach the binary from a plaintext string literal or an @objc member."
  echo "   Store the name ROT13-encoded and decode it at runtime, and don't declare"
  echo "   @objc stand-in classes that mirror Apple's selectors — guard on the missing"
  echo "   class instead. See Sources/SuperwallKit/Permissions/Handlers/."
  exit 1
fi

echo "✅ No privacy API signatures found."
