//
//  CustomerCenterPathResolverTests.swift
//
//
//  Created by Jordan Morgan on 20/08/2026.
//

import Testing
import Foundation
@testable import SuperwallKit

@Suite("CustomerCenterPathResolver")
struct CustomerCenterPathResolverTests {
  let now = Date(timeIntervalSince1970: 1_700_000_000)
  let paths = CustomerCenterConfiguration.default.managementScreen.paths
  let monthly = ProductDisplayInfo(productId: "monthly", title: "Monthly", localizedPrice: "$9.99", price: 9.99,
                                   localizedPeriod: "month", subscriptionGroupId: "g1", isAutoRenewable: true)

  func presentation(_ sub: SubscriptionTransaction, product: ProductDisplayInfo?) -> PurchasePresentation {
    PurchasePresentationBuilder(now: { now }, strings: .english)
      .build(customerInfo: CustomerInfo(subscriptions: [sub], nonSubscriptions: [], entitlements: []),
             products: product.map { [$0.productId: $0] } ?? [:])[0]
  }
  func sub(active: Bool = true, willRenew: Bool = true, expires: TimeInterval? = 86_400, revoked: Bool = false,
           offer: LatestSubscription.OfferType? = nil, store: ProductStore = .appStore, group: String? = "g1",
           purchasedAgo: TimeInterval = 86_400) -> SubscriptionTransaction {
    SubscriptionTransaction(transactionId: "t", productId: "monthly", purchaseDate: now.addingTimeInterval(-purchasedAgo),
      willRenew: willRenew, isRevoked: revoked, isInGracePeriod: false, isInBillingRetryPeriod: false, isActive: active,
      expirationDate: expires.map { now.addingTimeInterval($0) }, offerType: offer, subscriptionGroupId: group, store: store)
  }
  func context(_ purchase: PurchasePresentation?, product: ProductDisplayInfo? = nil, family: Bool = false, email: Bool = true,
               web: URL? = nil, changePlan: Bool = true, canOpen: Bool = true, isScreenLevel: Bool = false) -> PathResolutionContext {
    PathResolutionContext(purchase: purchase, product: product, isFamilyShared: family, supportEmailAvailable: email,
                          webManagementURL: web, isChangePlanSheetAvailable: changePlan, canOpenURLs: canOpen,
                          isScreenLevel: isScreenLevel, now: now)
  }
  func destinations(_ ctx: PathResolutionContext, _ paths: [CustomerCenterConfiguration.Path]? = nil) -> [ResolvedPathDestination] {
    CustomerCenterPathResolver.resolve(paths ?? self.paths, context: ctx).map(\.destination)
  }

  @Test("screen level (no purchase): restore, contactSupport, url, custom only")
  func screenLevel() {
    var p = paths
    p.append(.init(id: "faq", type: .url(URL(string: "https://a.b")!, openMethod: .inApp)))
    p.append(.init(id: "c", type: .custom(identifier: "x")))
    #expect(destinations(context(nil), p) == [.restore, .contactSupport, .url(URL(string: "https://a.b")!, inApp: true), .custom("x")])
  }

  @Test("active App Store sub with product: all default paths")
  func activeAppStore() {
    let ctx = context(presentation(sub(), product: monthly), product: monthly)
    #expect(destinations(ctx) == [.changePlan(groupId: "g1", productIds: nil), .refund(productId: "monthly"),
                                  .appleManageSheet(subscriptionGroupId: "g1"), .contactSupport])
  }

  @Test("restore hidden at purchase level; contactSupport hidden without email")
  func restoreAndEmail() {
    let ctx = context(presentation(sub(), product: monthly), product: monthly, email: false)
    #expect(!destinations(ctx).contains(.restore))
    #expect(!destinations(ctx).contains(.contactSupport))
  }

  @Test("restore stays available at screen level with a purchase, and is hidden once drilled in")
  func restoreIsScreenLevelOnly() {
    // The management screen's single-purchase layout passes its purchase so the other paths can
    // resolve, but restore must still be offered there — a user with one subscription may well
    // have other purchases to restore. Only the drilled-in detail screen hides it.
    let purchase = presentation(sub(), product: monthly)
    let screenLevel = destinations(context(purchase, product: monthly, isScreenLevel: true))
    #expect(screenLevel.contains(.restore))
    #expect(screenLevel.first == .restore)

    let drilledIn = destinations(context(purchase, product: monthly, isScreenLevel: false))
    #expect(!drilledIn.contains(.restore))

    // Screen level adds restore and changes nothing else.
    #expect(screenLevel.filter { $0 != .restore } == drilledIn)
  }

  @Test("cancelled sub: no manage sheet; expired: no manage/change; revoked: no refund/manage/change")
  func stateGating() {
    #expect(!destinations(context(presentation(sub(willRenew: false), product: monthly), product: monthly)).contains(.appleManageSheet(subscriptionGroupId: "g1")))
    let expired = destinations(context(presentation(sub(active: false, expires: -5), product: monthly), product: monthly))
    #expect(expired == [.refund(productId: "monthly"), .contactSupport])  // expired keeps refund (Apple allows), loses manage/change
    let revoked = destinations(context(presentation(sub(revoked: true), product: monthly), product: monthly))
    #expect(revoked == [.contactSupport])
  }

  @Test("refund: hidden for trial, $0 price, revoked, outside window; shown inside window")
  func refundGating() {
    #expect(!destinations(context(presentation(sub(offer: .trial), product: monthly), product: monthly)).contains(.refund(productId: "monthly")))
    let free = ProductDisplayInfo(productId: "monthly", title: "M", localizedPrice: "$0.00", price: 0, localizedPeriod: nil, subscriptionGroupId: "g1", isAutoRenewable: true)
    #expect(!destinations(context(presentation(sub(), product: free), product: free)).contains(.refund(productId: "monthly")))
    #expect(!destinations(context(presentation(sub(revoked: true), product: monthly), product: monthly)).contains(.refund(productId: "monthly")))
    let windowed = [CustomerCenterConfiguration.Path(id: "r", type: .refund(window: 3600))]
    #expect(destinations(context(presentation(sub(purchasedAgo: 7200), product: monthly), product: monthly), windowed).isEmpty)
    #expect(destinations(context(presentation(sub(purchasedAgo: 60), product: monthly), product: monthly), windowed) == [.refund(productId: "monthly")])
  }

  @Test("changePlan: curated ids, hidden when sheet unavailable, hidden without group")
  func changePlan() {
    let curated = [CustomerCenterConfiguration.Path(id: "c", type: .changePlan(productIds: ["a", "b"]))]
    #expect(destinations(context(presentation(sub(), product: monthly), product: monthly), curated) == [.changePlan(groupId: "g1", productIds: ["a", "b"])])
    #expect(destinations(context(presentation(sub(), product: monthly), product: monthly, changePlan: false), curated).isEmpty)
    let noGroup = ProductDisplayInfo(productId: "monthly", title: "M", localizedPrice: nil, price: nil, localizedPeriod: nil, subscriptionGroupId: nil, isAutoRenewable: true)
    #expect(destinations(context(presentation(sub(group: nil), product: noGroup), product: noGroup), curated).isEmpty)
  }

  @Test("web store sub: only webManage (when URL) + contactSupport; play store: contactSupport only")
  func otherStores() {
    let url = URL(string: "https://app.superwall.app/manage")!
    #expect(destinations(context(presentation(sub(store: .stripe), product: nil), web: url)) == [.webManage(url), .contactSupport])
    #expect(destinations(context(presentation(sub(store: .stripe), product: nil))) == [.contactSupport])
    #expect(destinations(context(presentation(sub(store: .playStore), product: nil))) == [.contactSupport])
  }

  @Test("family shared hides manage/refund/changePlan; app extension hides url/contact")
  func familyAndExtension() {
    #expect(destinations(context(presentation(sub(), product: monthly), product: monthly, family: true)) == [.contactSupport])
    var p = paths; p.append(.init(id: "faq", type: .url(URL(string: "https://a.b")!, openMethod: .external)))
    #expect(destinations(context(nil, canOpen: false), p) == [.restore])
  }
}
