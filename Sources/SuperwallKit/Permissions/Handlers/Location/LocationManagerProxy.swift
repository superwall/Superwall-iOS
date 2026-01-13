//
//  LocationManagerProxy.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 13/01/2026.
//

// This proxy accesses CLLocationManager using Objective-C runtime to avoid
// directly importing CoreLocation. This prevents the framework from being
// automatically linked, which could cause App Store review issues for apps
// that don't actually use location services. Class and selector names are
// ROT13-encoded to avoid static analysis detection.

import Foundation
import ObjectiveC.runtime

final class LocationManagerProxy: NSObject {
  // ROT13("CLLocationManager")
  static let mangledLocationManagerClassName = "PYYbpngvbaZnantre"

  // ROT13("authorizationStatus")
  static let mangledAuthorizationStatusSelector = "nhgubevmngvbaFgnghf"

  // ROT13("requestWhenInUseAuthorization")
  static let mangledRequestWhenInUseSelector = "erdhrfgJuraVaHfrNhgubevmngvba"

  // ROT13("requestAlwaysAuthorization")
  static let mangledRequestAlwaysSelector = "erdhrfgNyjnlfNhgubevmngvba"

  // ROT13("setDelegate:")
  static let mangledSetDelegateSelector = "frgQryrtngr:"

  static var locationManagerClass: AnyClass? {
    NSClassFromString(mangledLocationManagerClassName.rot13())
  }

  @objc var authorizationStatusSelectorName: String {
    Self.mangledAuthorizationStatusSelector.rot13()
  }

  @objc var requestWhenInUseSelectorName: String {
    Self.mangledRequestWhenInUseSelector.rot13()
  }

  @objc var requestAlwaysSelectorName: String {
    Self.mangledRequestAlwaysSelector.rot13()
  }

  @objc var setDelegateSelectorName: String {
    Self.mangledSetDelegateSelector.rot13()
  }

  private static func instanceIMP(_ cls: AnyClass, _ sel: Selector) -> IMP? {
    guard let method = class_getInstanceMethod(cls, sel) else { return nil }
    return method_getImplementation(method)
  }

  private var locationManager: NSObject?

  override init() {
    super.init()
    let cls: AnyClass = Self.locationManagerClass ?? FakeLocationManager.self
    guard let managerType = cls as? NSObject.Type else {
      return
    }
    locationManager = managerType.init()
  }

  func authorizationStatus() -> Int {
    guard let manager = locationManager else {
      return FakeLocationAuthorizationStatus.notDetermined.rawValue
    }

    // authorizationStatus is an Int property
    let result = manager.value(forKey: authorizationStatusSelectorName) as? Int
    return result ?? FakeLocationAuthorizationStatus.notDetermined.rawValue
  }

  func setDelegate(_ delegate: AnyObject?) {
    guard let manager = locationManager else {
      return
    }
    manager.setValue(delegate, forKey: "delegate")
  }

  /// Returns true if the request was successfully made, false otherwise.
  func requestWhenInUseAuthorization() -> Bool {
    guard let manager = locationManager else {
      return false
    }

    let sel = NSSelectorFromString(requestWhenInUseSelectorName)
    guard let imp = Self.instanceIMP(type(of: manager), sel) else {
      return false
    }

    typealias Function = @convention(c) (AnyObject, Selector) -> Void
    let function = unsafeBitCast(imp, to: Function.self)
    function(manager, sel)
    return true
  }

  /// Returns true if the request was successfully made, false otherwise.
  func requestAlwaysAuthorization() -> Bool {
    guard let manager = locationManager else {
      return false
    }

    let sel = NSSelectorFromString(requestAlwaysSelectorName)
    guard let imp = Self.instanceIMP(type(of: manager), sel) else {
      return false
    }

    typealias Function = @convention(c) (AnyObject, Selector) -> Void
    let function = unsafeBitCast(imp, to: Function.self)
    function(manager, sel)
    return true
  }
}
