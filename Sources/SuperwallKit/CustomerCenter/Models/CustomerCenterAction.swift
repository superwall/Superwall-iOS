//
//  CustomerCenterAction.swift
//
//
//  Created by Jordan Morgan on 20/08/2026.
//

import Foundation

/// An action the user selected in the Customer Center.
public enum CustomerCenterAction: Equatable, Sendable {
  case restore
  case manageSubscription
  case refund
  case changePlan
  case contactSupport
  case url(URL)
  case custom(identifier: String)

  init(pathType: CustomerCenterConfiguration.PathType) {
    switch pathType {
    case .restore: self = .restore
    case .manageSubscription: self = .manageSubscription
    case .refund: self = .refund
    case .changePlan: self = .changePlan
    case .contactSupport: self = .contactSupport
    case .url(let url, _): self = .url(url)
    case .custom(let identifier): self = .custom(identifier: identifier)
    }
  }

  /// Snake-case name used in events.
  var analyticsName: String {
    switch self {
    case .restore: return "restore"
    case .manageSubscription: return "manage_subscription"
    case .refund: return "refund"
    case .changePlan: return "change_plan"
    case .contactSupport: return "contact_support"
    case .url: return "url"
    case .custom: return "custom"
    }
  }
}

/// Objective-C representation of ``CustomerCenterAction``.
@objc(SWKCustomerCenterActionType)
public enum CustomerCenterActionTypeObjc: Int {
  case restore
  case manageSubscription
  case refund
  case changePlan
  case contactSupport
  case url
  case custom
}

@objc(SWKCustomerCenterAction)
@objcMembers
public final class CustomerCenterActionObjc: NSObject {
  public let type: CustomerCenterActionTypeObjc
  public let url: URL?
  public let customIdentifier: String?

  init(_ action: CustomerCenterAction) {
    switch action {
    case .restore: type = .restore; url = nil; customIdentifier = nil
    case .manageSubscription: type = .manageSubscription; url = nil; customIdentifier = nil
    case .refund: type = .refund; url = nil; customIdentifier = nil
    case .changePlan: type = .changePlan; url = nil; customIdentifier = nil
    case .contactSupport: type = .contactSupport; url = nil; customIdentifier = nil
    case .url(let value): type = .url; url = value; customIdentifier = nil
    case .custom(let identifier): type = .custom; url = nil; customIdentifier = identifier
    }
  }
}

/// Outcome of a refund request made from the Customer Center.
@objc(SWKCustomerCenterRefundStatus)
public enum CustomerCenterRefundStatus: Int, Sendable {
  case success
  case userCancelled
  case error

  var analyticsName: String {
    switch self {
    case .success: return "success"
    case .userCancelled: return "user_cancelled"
    case .error: return "error"
    }
  }
}
