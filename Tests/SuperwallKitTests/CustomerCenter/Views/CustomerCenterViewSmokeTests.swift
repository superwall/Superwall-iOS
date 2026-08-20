//
//  CustomerCenterViewSmokeTests.swift
//
//
//  Created by Claude on 20/08/2026.
//

import Testing
import SwiftUI
@testable import SuperwallKit

@Suite("CustomerCenterView smoke")
@MainActor
struct CustomerCenterViewSmokeTests {
  @Test("hosts without crashing in management and no-active states and exposes accessibility ids")
  @available(iOS 15.0, *)
  func hosts() async throws {
    let now = Date()
    let sub = SubscriptionTransaction(
      transactionId: "t",
      productId: "monthly",
      purchaseDate: now,
      willRenew: true,
      isRevoked: false,
      isInGracePeriod: false,
      isInBillingRetryPeriod: false,
      isActive: true,
      expirationDate: now.addingTimeInterval(86_400),
      offerType: nil,
      subscriptionGroupId: "g",
      store: .appStore
    )
    for info in [
      CustomerInfo(subscriptions: [sub], nonSubscriptions: [], entitlements: []),
      CustomerInfo(subscriptions: [], nonSubscriptions: [], entitlements: [])
    ] {
      let (deps, _, _) = CustomerCenterDependencies.mock(info: info)
      let model = CustomerCenterViewModel(configuration: .default, dependencies: deps, strings: .english)
      await model.load()
      let host = UIHostingController(rootView: CustomerCenterView(viewModel: model, navigationOptions: .default))
      host.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
      // A hosting controller only materializes its SwiftUI-backed subviews (e.g. `List`'s
      // internal UICollectionView) once it's part of a real window hierarchy — `loadViewIfNeeded()`
      // plus `layoutIfNeeded()` alone isn't enough to drive that pass in a headless test.
      let window = UIWindow(frame: host.view.frame)
      window.rootViewController = host
      window.makeKeyAndVisible()
      host.view.layoutIfNeeded()
      #expect(host.view.subviews.isEmpty == false)
      window.isHidden = true
    }
  }
}
