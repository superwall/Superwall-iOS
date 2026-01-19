//
//  AudioSessionProxy.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 19/01/2026.
//

// This proxy accesses AVAudioSession using Objective-C runtime to avoid
// directly importing AVFoundation framework. This prevents the framework from being
// automatically linked, which could cause App Store review issues for apps
// that don't actually use microphone. Class and selector names are ROT13-encoded
// to avoid static analysis detection.

import Foundation
import ObjectiveC.runtime

final class AudioSessionProxy: NSObject {
  // ROT13("AVAudioSession")
  static let mangledClassName = "NINhqvbFrffvba"

  // ROT13("sharedInstance")
  static let mangledSharedInstanceSelector = "funerqVafgnapr"

  // ROT13("recordPermission")
  static let mangledRecordPermissionSelector = "erpbeqCrezvffvba"

  // ROT13("requestRecordPermission:")
  static let mangledRequestPermissionSelector = "erdhrfgErpbeqCrezvffvba:"

  static var audioSessionClass: AnyClass? {
    NSClassFromString(mangledClassName.rot13())
  }

  private static func classIMP(_ cls: AnyClass, _ sel: Selector) -> IMP? {
    guard let method = class_getClassMethod(cls, sel) else { return nil }
    return method_getImplementation(method)
  }

  private static func instanceIMP(_ cls: AnyClass, _ sel: Selector) -> IMP? {
    guard let method = class_getInstanceMethod(cls, sel) else { return nil }
    return method_getImplementation(method)
  }

  func sharedInstance() -> AnyObject? {
    let cls: AnyClass = Self.audioSessionClass ?? FakeAudioSession.self
    let sel = NSSelectorFromString(Self.mangledSharedInstanceSelector.rot13())

    guard let imp = Self.classIMP(cls, sel) else { return nil }

    typealias Function = @convention(c) (AnyObject, Selector) -> AnyObject
    let function = unsafeBitCast(imp, to: Function.self)

    return function(cls as AnyObject, sel)
  }

  // AVAudioSession.RecordPermission raw values:
  // 0x756e6474 ('undt') = undetermined
  // 0x64656e79 ('deny') = denied
  // 0x67726e74 ('grnt') = granted
  func recordPermission() -> Int {
    let cls: AnyClass = Self.audioSessionClass ?? FakeAudioSession.self

    guard let instance = sharedInstance() else {
      return -1
    }

    let sel = NSSelectorFromString(Self.mangledRecordPermissionSelector.rot13())
    guard let imp = Self.instanceIMP(cls, sel) else { return -1 }

    typealias Function = @convention(c) (AnyObject, Selector) -> Int
    let function = unsafeBitCast(imp, to: Function.self)

    return function(instance, sel)
  }

  func requestRecordPermission() async -> Bool {
    let cls: AnyClass = Self.audioSessionClass ?? FakeAudioSession.self

    guard let instance = sharedInstance() else {
      return false
    }

    let sel = NSSelectorFromString(Self.mangledRequestPermissionSelector.rot13())
    guard let imp = Self.instanceIMP(cls, sel) else { return false }

    return await withCheckedContinuation { continuation in
      let completion: @convention(block) (Bool) -> Void = { granted in
        continuation.resume(returning: granted)
      }

      typealias Function = @convention(c) (AnyObject, Selector, AnyObject) -> Void
      let function = unsafeBitCast(imp, to: Function.self)

      function(instance, sel, completion as AnyObject)
    }
  }
}
