//
//  CustomerCenterPathResolver.swift
//
//
//  Created by Jordan Morgan on 20/08/2026.
//

import Foundation

struct PathResolutionContext {
  var purchase: PurchasePresentation?
  var product: ProductDisplayInfo?
  var isFamilyShared = false
  var supportEmailAvailable: Bool
  var webManagementURL: URL?
  var isChangePlanSheetAvailable: Bool
  var canOpenURLs = true
  var now = Date()
}

enum ResolvedPathDestination: Equatable {
  case restore
  case appleManageSheet(subscriptionGroupId: String?)
  case webManage(URL)
  case refund(productId: String)
  case changePlan(groupId: String?, productIds: [String]?)
  case contactSupport
  case url(URL, inApp: Bool)
  case custom(String)
}

struct ResolvedPath: Equatable, Identifiable {
  var id: String { path.id }
  var path: CustomerCenterConfiguration.Path
  var destination: ResolvedPathDestination
}

enum CustomerCenterPathResolver {
  static func resolve(
    _ paths: [CustomerCenterConfiguration.Path],
    context: PathResolutionContext
  ) -> [ResolvedPath] {
    paths.compactMap { path in
      destination(for: path, context: context).map { ResolvedPath(path: path, destination: $0) }
    }
  }

  private static func destination(
    for path: CustomerCenterConfiguration.Path,
    context: PathResolutionContext
  ) -> ResolvedPathDestination? {
    let purchase = context.purchase
    let sub = purchase?.subscription
    let isAppStore = purchase?.store == .appStore
    let isWebStore = [.stripe, .paddle, .superwall].contains(purchase?.store ?? .other)

    switch path.type {
    case .restore:
      return purchase == nil ? .restore : nil

    case .contactSupport:
      return context.supportEmailAvailable && context.canOpenURLs ? .contactSupport : nil

    case let .url(url, method):
      guard context.canOpenURLs else { return nil }
      let isWeb = ["http", "https"].contains(url.scheme?.lowercased() ?? "")
      return .url(url, inApp: method == .inApp && isWeb)

    case .custom(let identifier):
      return .custom(identifier)

    case .manageSubscription:
      guard let purchase else { return nil }
      if isAppStore {
        guard
          let sub, sub.isActive, sub.willRenew, !sub.isRevoked,
          sub.expirationDate != nil, !context.isFamilyShared
        else { return nil }
        return .appleManageSheet(subscriptionGroupId: sub.subscriptionGroupId ?? context.product?.subscriptionGroupId)
      }
      if isWebStore, let url = context.webManagementURL {
        return .webManage(url)
      }
      return nil

    case .refund(let window):
      guard isAppStore, let sub, !sub.isRevoked, sub.offerType != .trial, !context.isFamilyShared else { return nil }
      if let price = context.product?.price, price <= 0 { return nil }
      if let window, sub.purchaseDate.addingTimeInterval(window) < context.now { return nil }
      return .refund(productId: sub.productId)

    case .changePlan(let productIds):
      guard
        isAppStore, let sub, sub.isActive, !sub.isRevoked, !context.isFamilyShared,
        context.isChangePlanSheetAvailable,
        purchase?.badge != .lifetime,
        context.product?.isAutoRenewable != false
      else { return nil }
      let groupId = sub.subscriptionGroupId ?? context.product?.subscriptionGroupId
      guard groupId != nil else { return nil }
      return .changePlan(groupId: groupId, productIds: productIds)
    }
  }
}
