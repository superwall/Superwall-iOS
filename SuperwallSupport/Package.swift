// swift-tools-version:5.9
// SuperwallSupport: the Support add-on (plan decision 42).
//
// A separate package from SuperwallKit on purpose. It never imports core's Swift
// types (core is built without library evolution, so a binary can't link them);
// it talks to core through a Foundation-types bridge, found by class name at
// configure. This milestone (M1) is the transport layer only: no UI, no bridge.

import PackageDescription

let package = Package(
  name: "SuperwallSupport",
  platforms: [
    .iOS(.v15),
    // macOS so the transport and its fixture tests run with `swift test` on a laptop.
    .macOS(.v12)
  ],
  products: [
    .library(name: "SuperwallSupport", targets: ["SuperwallSupport"])
  ],
  targets: [
    .target(
      name: "SuperwallSupport",
      path: "Sources/SuperwallSupport"
    ),
    .testTarget(
      name: "SuperwallSupportTests",
      dependencies: ["SuperwallSupport"],
      path: "Tests/SuperwallSupportTests",
      resources: [.copy("Fixtures")]
    )
  ]
)
