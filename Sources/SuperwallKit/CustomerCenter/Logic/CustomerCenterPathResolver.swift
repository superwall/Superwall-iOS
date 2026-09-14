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
  /// `true` when resolving a screen's main action list (management / no-active), where restore
  /// is always available; `false` when resolving a drilled-in purchase detail screen.
  var isScreenLevel = false
  var now = Date()
}

enum ResolvedPathDestination: Equatable {
  case restore
  case appleManageSheet(subscriptionGroupId: String?)
  case webManage(URL)
  /// A web-store subscription with no management page configured. There's nowhere to send the
  /// customer, so the row explains where to find the link instead of disappearing and leaving
  /// them with no way to manage a subscription they're paying for.
  case webManageUnavailable
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

extension ResolvedPathDestination {
  /// Whether this destination hands the customer off to a web management page — or explains that
  /// there isn't one. Surveys are skipped for these: the survey gates an action, and here the
  /// action either leaves the app entirely or can't be performed at all.
  var isWebManagement: Bool {
    switch self {
    case .webManage, .webManageUnavailable: return true
    default: return false
    }
  }
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

  /// Split out of `destination(for:context:)` to keep that switch under the complexity limit.
  private static func manageSubscriptionDestination(
    context: PathResolutionContext
  ) -> ResolvedPathDestination? {
    guard let purchase = context.purchase else { return nil }
    let sub = purchase.subscription

    if purchase.store == .appStore {
      guard
        let sub, sub.isActive, sub.willRenew, !sub.isRevoked,
        sub.expirationDate != nil, !context.isFamilyShared
      else { return nil }
      return .appleManageSheet(subscriptionGroupId: sub.subscriptionGroupId ?? context.product?.subscriptionGroupId)
    }

    guard [.stripe, .paddle, .superwall].contains(purchase.store) else { return nil }

    // A one-off purchase has nothing to manage, and neither has a subscription that has lapsed or
    // been revoked. The App Store branch above gates on both; this one gated on neither, so a
    // single Stripe charge and an expired web subscription were each offered a management row.
    switch purchase.kind {
    case .nonSubscription: return nil
    case .subscription(let sub) where sub.isRevoked: return nil
    default: break
    }
    guard purchase.isActive else { return nil }

    // A comped grant — an entitlement with no transaction *and* no store behind it — has nothing
    // to manage anywhere, so offer the page only if one exists and never claim a receipt was
    // sent. The signal is the nil store, not the missing transaction: a web purchase arrives as a
    // bare entitlement whenever the backend sends no matching transaction, and that entitlement
    // still carries its store. Keying on the kind alone would take the row back off the paying
    // customers it exists for.
    if case .entitlementOnly(let entitlement) = purchase.kind, entitlement.store == nil {
      return context.webManagementURL.map { ResolvedPathDestination.webManage($0) }
    }
    return context.webManagementURL.map { ResolvedPathDestination.webManage($0) } ?? .webManageUnavailable
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
      // Restore is always available at screen level (even when the screen's single-purchase
      // layout passes its purchase for the other paths); it's only hidden on drilled-in
      // purchase detail screens.
      return purchase == nil || context.isScreenLevel ? .restore : nil

    case .contactSupport:
      return context.supportEmailAvailable && context.canOpenURLs ? .contactSupport : nil

    case let .url(url, _, method):
      guard context.canOpenURLs else { return nil }
      let isWeb = ["http", "https"].contains(url.scheme?.lowercased() ?? "")
      return .url(url, inApp: method == .inApp && isWeb)

    case .custom(let identifier):
      return .custom(identifier)

    case .manageSubscription:
      return manageSubscriptionDestination(context: context)

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
