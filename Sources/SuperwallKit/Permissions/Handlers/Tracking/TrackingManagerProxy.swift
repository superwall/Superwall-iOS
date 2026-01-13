//
//  TrackingManagerProxy.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 13/01/2026.
//

// This proxy accesses ATTrackingManager using Objective-C runtime to avoid
// directly importing AppTrackingTransparency. This prevents the framework from being
// automatically linked, which could cause App Store review issues for apps
// that don't actually use tracking. Class and selector names are ROT13-encoded
// to avoid static analysis detection.

import Foundation
import ObjectiveC.runtime

final class TrackingManagerProxy: NSObject {
  // ROT13("ATTrackingManager")
  static let mangledTrackingManagerClassName = "NGGenpxvatZnantre"

  // ROT13("trackingAuthorizationStatus")
  static let mangledTrackingStatusSelector = "genpxvatNhgubevmngvbaFgnghf"

  // ROT13("requestTrackingAuthorizationWithCompletionHandler:")
  static let mangledRequestTrackingSelector =
    "erdhrfgGenpxvatNhgubevmngvbaJvguPbzcyrgvbaUnaqyre:"

  static var trackingManagerClass: AnyClass? {
    NSClassFromString(mangledTrackingManagerClassName.rot13())
  }

  @objc var trackingStatusSelectorName: String {
    Self.mangledTrackingStatusSelector.rot13()
  }

  @objc var requestTrackingSelectorName: String {
    Self.mangledRequestTrackingSelector.rot13()
  }

  private static func classIMP(_ cls: AnyClass, _ sel: Selector) -> IMP? {
    guard let method = class_getClassMethod(cls, sel) else { return nil }
    return method_getImplementation(method)
  }

  func trackingAuthorizationStatus() -> Int {
    let cls: AnyClass = Self.trackingManagerClass ?? FakeTrackingManager.self
    let sel = NSSelectorFromString(trackingStatusSelectorName)

    guard let imp = Self.classIMP(cls, sel) else {
      return FakeTrackingAuthorizationStatus.notDetermined.rawValue
    }

    typealias Function = @convention(c) (AnyObject, Selector) -> Int
    let function = unsafeBitCast(imp, to: Function.self)
    return function(cls as AnyObject, sel)
  }

  func requestTrackingAuthorization() async -> Int {
    let cls: AnyClass = Self.trackingManagerClass ?? FakeTrackingManager.self
    let sel = NSSelectorFromString(requestTrackingSelectorName)

    guard let imp = Self.classIMP(cls, sel) else {
      return FakeTrackingAuthorizationStatus.notDetermined.rawValue
    }

    return await withCheckedContinuation { continuation in
      let completion: @convention(block) (Int) -> Void = { status in
        continuation.resume(returning: status)
      }

      typealias Function = @convention(c) (AnyObject, Selector, AnyObject) -> Void
      let function = unsafeBitCast(imp, to: Function.self)
      function(cls as AnyObject, sel, completion as AnyObject)
    }
  }
}
