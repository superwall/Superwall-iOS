//
//  FoldStateScript.swift
//  SuperwallKit
//
//  Created by Superwall on 16/10/2026.
//

import UIKit

/// The fold state of a foldable display, shaped like the W3C Device Posture
/// and Viewport Segments APIs that WKWebView does not expose.
///
/// The paywall reads `window.__SW_FOLD__` and listens for `superwall:fold`.
struct FoldState: Equatable {
  enum Posture: String {
    case continuous
    case folded
  }

  let posture: Posture
  let segments: [CGRect]

  /// Splits `bounds` along the first active division region whose centre line
  /// crosses it, the way WebKit reports viewport segments when its fold APIs
  /// are enabled. A division that only overlaps an edge leaves one segment.
  init(bounds: CGRect, activeDivisions: [CGRect]) {
    for fold in activeDivisions {
      let isVertical = fold.width < fold.height
      if isVertical, fold.midX > bounds.minX, fold.midX < bounds.maxX {
        let split = fold.midX - bounds.minX
        posture = .folded
        segments = [
          CGRect(x: bounds.minX, y: bounds.minY, width: split, height: bounds.height),
          CGRect(x: bounds.minX + split, y: bounds.minY, width: bounds.width - split, height: bounds.height)
        ]
        return
      }
      if !isVertical, fold.midY > bounds.minY, fold.midY < bounds.maxY {
        let split = fold.midY - bounds.minY
        posture = .folded
        segments = [
          CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: split),
          CGRect(x: bounds.minX, y: bounds.minY + split, width: bounds.width, height: bounds.height - split)
        ]
        return
      }
    }
    posture = .continuous
    segments = [bounds]
  }

  /// Reads the view's active division regions through UIKit's public
  /// `-reservedRegionsOfKind:` (iOS 27.1). It is called by selector so the SDK
  /// still builds with Xcode 26; earlier systems report a continuous display.
  @MainActor
  static func read(from view: UIView) -> FoldState {
    FoldState(bounds: view.bounds, activeDivisions: activeDivisionFrames(in: view))
  }

  @MainActor
  private static func activeDivisionFrames(in view: UIView) -> [CGRect] {
    let kindSelector = NSSelectorFromString("divisionRegionKind")
    let querySelector = NSSelectorFromString("reservedRegionsOfKind:")
    guard
      let kindClass = NSClassFromString("UIViewReservedRegionKind") as AnyObject?,
      kindClass.responds(to: kindSelector),
      view.responds(to: querySelector),
      let kind = kindClass.perform(kindSelector)?.takeUnretainedValue(),
      let regions = view.perform(querySelector, with: kind)?.takeUnretainedValue() as? [NSObject]
    else {
      return []
    }
    return regions.compactMap { ($0.value(forKey: "frame") as? NSValue)?.cgRectValue }
  }

  var script: String {
    let rects = segments.map { [$0.minX, $0.minY, $0.width, $0.height] }
    let payload: [String: Any] = ["posture": posture.rawValue, "segments": rects]
    guard
      let data = try? JSONSerialization.data(withJSONObject: payload),
      let json = String(data: data, encoding: .utf8)
    else {
      return ""
    }
    return "window.__SW_FOLD__ = \(json); window.dispatchEvent(new Event('superwall:fold'));"
  }
}
