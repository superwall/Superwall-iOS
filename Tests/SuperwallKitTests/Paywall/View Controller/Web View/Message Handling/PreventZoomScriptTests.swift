//
//  PreventZoomScriptTests.swift
//  SuperwallKitTests
//
//  Created by Superwall on 16/10/2026.
//

import Testing
@testable import SuperwallKit

struct PreventZoomScriptTests {
  /// The tag appended before 4.18.1, verbatim.
  static let legacyPreventZoomScript =
    "var meta = document.createElement('meta');" + "meta.name = 'viewport';"
    + "meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';"
    + "var head = document.getElementsByTagName('head')[0];" + "head.appendChild(meta);"

  @Test("Differs from the tag before 4.18.1 only by viewport-fit=cover")
  func onlyAddsViewportFitCover() {
    let expected = Self.legacyPreventZoomScript.replacingOccurrences(
      of: "user-scalable=no'",
      with: "user-scalable=no, viewport-fit=cover'"
    )
    #expect(expected != Self.legacyPreventZoomScript)
    #expect(PaywallMessageHandler.preventZoomScript == expected)
  }
}
