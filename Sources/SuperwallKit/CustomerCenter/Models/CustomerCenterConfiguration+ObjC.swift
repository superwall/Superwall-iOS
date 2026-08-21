//
//  CustomerCenterConfiguration+ObjC.swift
//
//
//  Created by Jordan Morgan on 20/08/2026.
//

import Foundation

/// Objective-C mirror of ``CustomerCenterConfiguration/PathType``.
@objc(SWKCustomerCenterPathType)
public enum CustomerCenterPathTypeObjc: Int {
  case restore, manageSubscription, refund, changePlan, contactSupport, url, custom
}

@objc(SWKCustomerCenterOpenMethod)
public enum CustomerCenterOpenMethodObjc: Int {
  case inApp, external
}

extension CustomerCenterConfiguration.Path {
  /// The path's type, for Objective-C.
  @objc public var pathType: CustomerCenterPathTypeObjc {
    switch type {
    case .restore: return .restore
    case .manageSubscription: return .manageSubscription
    case .refund: return .refund
    case .changePlan: return .changePlan
    case .contactSupport: return .contactSupport
    case .url: return .url
    case .custom: return .custom
    }
  }
  @objc public var url: URL? {
    if case .url(let url, _) = type { return url }
    return nil
  }
  @objc public var openMethodObjc: CustomerCenterOpenMethodObjc {
    if case .url(_, let method) = type, method == .external { return .external }
    return .inApp
  }
  @objc public var customIdentifier: String? {
    if case .custom(let id) = type { return id }
    return nil
  }
  @objc public var refundWindow: NSNumber? {
    if case .refund(let window) = type, let window { return NSNumber(value: window) }
    return nil
  }
  @objc public var changePlanProductIds: [String]? {
    if case .changePlan(let ids) = type { return ids }
    return nil
  }

  @objc public static func restore(id: String, title: String?) -> CustomerCenterConfiguration.Path {
    .init(id: id, type: .restore, title: title)
  }
  @objc public static func manageSubscription(id: String, title: String?) -> CustomerCenterConfiguration.Path {
    .init(id: id, type: .manageSubscription, title: title)
  }
  @objc public static func refund(id: String, window: NSNumber?, title: String?) -> CustomerCenterConfiguration.Path {
    .init(id: id, type: .refund(window: window?.doubleValue), title: title)
  }
  @objc public static func changePlan(id: String, productIds: [String]?, title: String?) -> CustomerCenterConfiguration.Path {
    .init(id: id, type: .changePlan(productIds: productIds), title: title)
  }
  @objc public static func contactSupport(id: String, title: String?) -> CustomerCenterConfiguration.Path {
    .init(id: id, type: .contactSupport, title: title)
  }
  @objc public static func url(id: String, url: URL, openMethod: CustomerCenterOpenMethodObjc, title: String?) -> CustomerCenterConfiguration.Path {
    .init(id: id, type: .url(url, openMethod: openMethod == .external ? .external : .inApp), title: title)
  }
  @objc public static func custom(id: String, identifier: String, title: String?) -> CustomerCenterConfiguration.Path {
    .init(id: id, type: .custom(identifier: identifier), title: title)
  }
}
