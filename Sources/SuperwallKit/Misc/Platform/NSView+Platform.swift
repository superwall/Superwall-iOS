//
//  NSView+Platform.swift
//  SuperwallKit
//
//  Created by Brian Anglin on 13/10/2026.
//
// UIView's names for the handful of view operations the paywall's shared
// code uses, so that code reads the same on both platforms.

#if os(macOS)
import AppKit

extension NSView {
  var alpha: CGFloat {
    get { alphaValue }
    set { alphaValue = newValue }
  }

  /// Drawn by the view's layer, which this turns on.
  var backgroundColor: NSColor? {
    get {
      return layer?.backgroundColor.flatMap { NSColor(cgColor: $0) }
    }
    set {
      wantsLayer = true
      layer?.backgroundColor = newValue?.cgColor
    }
  }

  func insertSubview(_ view: NSView, belowSubview siblingSubview: NSView) {
    addSubview(view, positioned: .below, relativeTo: siblingSubview)
  }

  /// Animates the changes `animations` makes to layer-backed views, like
  /// `UIView.animate`.
  ///
  /// Unlike UIKit, the changes themselves wait for `delay` to pass.
  static func animate(
    withDuration duration: TimeInterval,
    delay: TimeInterval = 0,
    animations: @escaping () -> Void,
    completion: ((Bool) -> Void)? = nil
  ) {
    animate(
      withDuration: duration,
      delay: delay,
      timingFunction: CAMediaTimingFunction(name: .easeInEaseOut),
      animations: animations,
      completion: completion
    )
  }

  /// AppKit has no spring curve, so this eases out fast and settles, which is
  /// the shape of the spring UIKit uses.
  static func springAnimate(
    withDuration duration: TimeInterval = 0.618,
    delay: TimeInterval = 0,
    animations: @escaping () -> Void,
    completion: ((Bool) -> Void)? = nil
  ) {
    animate(
      withDuration: duration,
      delay: delay,
      timingFunction: CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.3, 1),
      animations: animations,
      completion: completion
    )
  }

  private static func animate(
    withDuration duration: TimeInterval,
    delay: TimeInterval,
    timingFunction: CAMediaTimingFunction,
    animations: @escaping () -> Void,
    completion: ((Bool) -> Void)?
  ) {
    let run = {
      NSAnimationContext.runAnimationGroup(
        { context in
          context.duration = duration
          context.timingFunction = timingFunction
          context.allowsImplicitAnimation = true
          animations()
        },
        completionHandler: {
          completion?(true)
        }
      )
    }
    if delay > 0 {
      DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: run)
    } else {
      run()
    }
  }
}
#endif
