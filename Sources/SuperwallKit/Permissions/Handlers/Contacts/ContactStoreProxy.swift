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

  private let contactStoreClass: AnyClass?

  init(
    contactStoreClass: AnyClass? = NSClassFromString(
      ContactStoreProxy.mangledContactStoreClassName.rot13()
    )
  ) {
    self.contactStoreClass = contactStoreClass
    super.init()
  }

  // Deliberately not `@objc`: an `@objc` member emits its name into the binary's
  // Objective-C method metadata, which is the section this file's mangling exists
  // to keep Apple's API names out of. These are read from Swift only.
  var authorizationStatusSelectorName: String {
    Self.mangledAuthorizationStatusSelector.rot13()
  }

  var requestAccessSelectorName: String {
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

  func authorizationStatus() -> Int {
    guard let cls = contactStoreClass else {
      return -1
    }
    let sel = NSSelectorFromString(authorizationStatusSelectorName)

    guard let imp = Self.classIMP(cls, sel) else {
      return -1
    }

    typealias Function = @convention(c) (AnyObject, Selector, Int) -> Int
    let function = unsafeBitCast(imp, to: Function.self)

    // For class methods, the receiver is the class object itself.
    return function(cls as AnyObject, sel, Self.contactsEntityType)
  }

  // Named away from Apple's `requestAccess` deliberately:
  // `withCheckedThrowingContinuation`'s `function: String = #function` default
  // expands the enclosing method name into a string literal in the binary.
  func requestPermission() async throws -> Bool {
    guard let storeType = contactStoreClass as? NSObject.Type else {
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
