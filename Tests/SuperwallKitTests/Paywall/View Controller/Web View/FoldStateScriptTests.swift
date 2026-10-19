//
//  FoldStateScriptTests.swift
//  SuperwallKitTests
//
//  Created by Superwall on 16/10/2026.
//

import Testing
import UIKit
@testable import SuperwallKit

struct FoldStateScriptTests {
  @Test("A display without an active fold is one continuous segment")
  func continuousWithoutActiveDivision() {
    let bounds = CGRect(x: 0, y: 0, width: 466, height: 678)
    let state = FoldState(bounds: bounds, activeDivisions: [])
    #expect(state.posture == .continuous)
    #expect(state.segments == [bounds])
  }

  @Test("A horizontal fold splits the display into top and bottom segments")
  func horizontalFoldSplitsVertically() {
    let state = FoldState(
      bounds: CGRect(x: 0, y: 0, width: 669, height: 951),
      activeDivisions: [CGRect(x: 0, y: 456, width: 669, height: 40)]
    )
    #expect(state.posture == .folded)
    #expect(state.segments == [
      CGRect(x: 0, y: 0, width: 669, height: 476),
      CGRect(x: 0, y: 476, width: 669, height: 475)
    ])
  }

  @Test("A vertical fold splits the display into left and right segments")
  func verticalFoldSplitsHorizontally() {
    let state = FoldState(
      bounds: CGRect(x: 0, y: 0, width: 951, height: 669),
      activeDivisions: [CGRect(x: 456, y: 0, width: 40, height: 669)]
    )
    #expect(state.posture == .folded)
    #expect(state.segments.map(\.width) == [476, 475])
  }

  @Test("A division outside the view's bounds is ignored")
  func ignoresDivisionOutsideBounds() {
    let state = FoldState(
      bounds: CGRect(x: 0, y: 0, width: 300, height: 600),
      activeDivisions: [CGRect(x: 456, y: 0, width: 40, height: 669)]
    )
    #expect(state.posture == .continuous)
  }

  @Test("A horizontal division that only overlaps the bottom edge leaves one segment")
  func ignoresHorizontalDivisionAtEdge() {
    let bounds = CGRect(x: 0, y: 0, width: 669, height: 470)
    let state = FoldState(bounds: bounds, activeDivisions: [CGRect(x: 0, y: 456, width: 669, height: 40)])
    #expect(state.posture == .continuous)
    #expect(state.segments == [bounds])
  }

  @Test("A vertical division that only overlaps the right edge leaves one segment")
  func ignoresVerticalDivisionAtEdge() {
    let bounds = CGRect(x: 0, y: 0, width: 470, height: 669)
    let state = FoldState(bounds: bounds, activeDivisions: [CGRect(x: 456, y: 0, width: 40, height: 669)])
    #expect(state.posture == .continuous)
    #expect(state.segments == [bounds])
  }

  @Test("The script sets the global and notifies the page")
  func scriptPublishesState() {
    let state = FoldState(bounds: CGRect(x: 0, y: 0, width: 10, height: 20), activeDivisions: [])
    #expect(state.script.hasPrefix("window.__SW_FOLD__ = {"))
    #expect(state.script.contains(#""posture":"continuous""#))
    #expect(state.script.hasSuffix("window.dispatchEvent(new Event('superwall:fold'));"))
  }
}
