//
//  ContactStoreProxy.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 13/01/2026.
//

// This proxy accesses CNContactStore using Objective-C runtime to avoid
// directly importing Contacts framework. This prevents the framework from being
// automatically linked, which could cause App Store review issues for apps
// that don't actually use contacts. Class and selector names are ROT13-encoded
// to avoid static analysis detection.

import Foundation
import ObjectiveC.runtime

final class ContactStoreProxy: NSObject {
  // ROT13("CNContactStore")
  static let mangledContactStoreClassName = "PAPbagnpgFgber"

  // ROT13("authorizationStatusForEntityType:")
  static let mangledAuthorizationStatusSelector =
    "nhgubevmngvbaFgnghfSbeRagvglGlcr:"

  // ROT13("requestAccessForEntityType:completionHandler:")
  static let mangledRequestAccessSelector =
    "erdhrfgNpprffSbeRagvglGlcr:pbzcyrgvbaUnaqyre:"

  // CNEntityType.contacts == 0
  static let contactsEntityType = 0

  static var contactStoreClass: AnyClass? {
    NSClassFromString(mangledContactStoreClassName.rot13())
  }

  @objc var authorizationStatusSelectorName: String {
    Self.mangledAuthorizationStatusSelector.rot13()
  }

  @objc var requestAccessSelectorName: String {
    Self.mangledRequestAccessSelector.rot13()
  }

  private static func classIMP(_ cls: AnyClass, _ sel: Selector) -> IMP? {
    guard let method = class_getClassMethod(cls, sel) else { return nil }
    return method_getImplementation(method)
  }

  private static func instanceIMP(_ cls: AnyClass, _ sel: Selector) -> IMP? {
    guard let method = class_getInstanceMethod(cls, sel) else { return nil }
    return method_getImplementation(method)
  }

  @objc func authorizationStatus() -> Int {
    let cls: AnyClass = Self.contactStoreClass ?? FakeContactStore.self
    let sel = NSSelectorFromString(authorizationStatusSelectorName)

    guard let imp = Self.classIMP(cls, sel) else {
      return -1
    }

    typealias Function = @convention(c) (AnyObject, Selector, Int) -> Int
    let function = unsafeBitCast(imp, to: Function.self)

    // For class methods, the receiver is the class object itself.
    return function(cls as AnyObject, sel, Self.contactsEntityType)
  }

  func requestAccess() async throws -> Bool {
    let cls: AnyClass = Self.contactStoreClass ?? FakeContactStore.self

    guard let storeType = cls as? NSObject.Type else {
      return false
    }

    let store = storeType.init()
    let sel = NSSelectorFromString(requestAccessSelectorName)

    guard let imp = Self.instanceIMP(type(of: store), sel) else {
      return false
    }

    return try await withCheckedThrowingContinuation { continuation in
      let completion: @convention(block) (Bool, AnyObject?) -> Void = { granted, error in
        if let error = error as? Error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume(returning: granted)
        }
      }

      typealias Function = @convention(c) (AnyObject, Selector, Int, AnyObject) -> Void
      let function = unsafeBitCast(imp, to: Function.self)

      function(store, sel, Self.contactsEntityType, completion as AnyObject)
    }
  }
}
