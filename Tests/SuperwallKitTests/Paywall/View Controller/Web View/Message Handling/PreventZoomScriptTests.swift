//
//  PreventZoomScriptTests.swift
//  SuperwallKitTests
//
//  Created by Superwall on 16/10/2026.
//

import Testing
@testable import SuperwallKit

struct PreventZoomScriptTests {
  @Test("Keeps viewport-fit=cover so safe-area insets reach the paywall")
  func keepsViewportFitCover() {
    #expect(PaywallMessageHandler.preventZoomScript.contains("viewport-fit=cover"))
  }

  @Test("Still disables zooming")
  func disablesZoom() {
    let script = PaywallMessageHandler.preventZoomScript
    #expect(script.contains("user-scalable=no"))
    #expect(script.contains("maximum-scale=1.0"))
  }
}
