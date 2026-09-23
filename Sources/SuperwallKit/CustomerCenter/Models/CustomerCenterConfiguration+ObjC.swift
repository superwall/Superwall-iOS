//
//  CustomerCenterConfiguration+ObjC.swift
//
//
//  Created by Jordan Morgan on 20/08/2026.
//

import Foundation

@objc(SWKCustomerCenterOpenMethod)
public enum CustomerCenterOpenMethodObjc: Int {
  case inApp, external
}

extension CustomerCenterConfiguration.Path {
  /// What the path does, for Objective-C: the same values its taps report as.
  @objc public var actionType: CustomerCenterActionTypeObjc {
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

  @available(swift, obsoleted: 1.0)
  @objc(restoreWithId:title:)
  public static func restoreObjc(id: String?, title: String?) -> CustomerCenterConfiguration.Path {
    .init(id: id, type: .restore, title: title)
  }
  @available(swift, obsoleted: 1.0)
  @objc(manageSubscriptionWithId:title:)
  public static func manageSubscriptionObjc(id: String?, title: String?) -> CustomerCenterConfiguration.Path {
    .init(id: id, type: .manageSubscription, title: title)
  }
  @available(swift, obsoleted: 1.0)
  @objc(refundWithId:window:title:)
  public static func refundObjc(id: String?, window: NSNumber?, title: String?) -> CustomerCenterConfiguration.Path {
    .init(id: id, type: .refund(window: window?.doubleValue), title: title)
  }
  @available(swift, obsoleted: 1.0)
  @objc(changePlanWithId:productIds:title:)
  public static func changePlanObjc(id: String?, productIds: [String]?, title: String?) -> CustomerCenterConfiguration.Path {
    .init(id: id, type: .changePlan(productIds: productIds), title: title)
  }
  @available(swift, obsoleted: 1.0)
  @objc(contactSupportWithId:title:)
  public static func contactSupportObjc(id: String?, title: String?) -> CustomerCenterConfiguration.Path {
    .init(id: id, type: .contactSupport, title: title)
  }
  /// `title` is non-optional here, unlike the other path factories: a URL row has no default
  /// name to fall back on.
  @available(swift, obsoleted: 1.0)
  @objc(urlWithId:url:openMethod:title:)
  public static func urlObjc(id: String?, url: URL, openMethod: CustomerCenterOpenMethodObjc, title: String) -> CustomerCenterConfiguration.Path {
    .init(
      id: id,
      type: .url(url, openMethod: openMethod == .external ? .external : .inApp),
      title: title
    )
  }
  @available(swift, obsoleted: 1.0)
  @objc(customWithId:identifier:title:)
  public static func customObjc(id: String?, identifier: String, title: String?) -> CustomerCenterConfiguration.Path {
    .init(id: id, type: .custom(identifier: identifier), title: title)
  }
}
