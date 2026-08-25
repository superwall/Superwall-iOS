//
//  ManagementScreenViewTests.swift
//
//
//  Created by Jordan Morgan on 25/08/2026.
//

import Testing
import Foundation
@testable import SuperwallKit

@Suite("ManagementScreenView inline purchases")
@MainActor
struct ManagementScreenViewTests {
  @available(iOS 15.0, *)
  private func makeViewModel(
    nonSubscriptionCount: Int,
    showsPurchaseHistory: Bool
  ) async -> CustomerCenterViewModel {
    let now = Date()
    let purchases = (0..<nonSubscriptionCount).map { index in
      NonSubscriptionTransaction(
        transactionId: "t\(index)",
        productId: "lifetime\(index)",
        purchaseDate: now.addingTimeInterval(TimeInterval(-index)),
        isConsumable: false,
        isRevoked: false,
        store: .appStore
      )
    }
    let (deps, _, _) = CustomerCenterDependencies.mock(
      info: CustomerInfo(subscriptions: [], nonSubscriptions: purchases, entitlements: [])
    )
    let configuration = CustomerCenterConfiguration.default
    configuration.showsPurchaseHistory = showsPurchaseHistory
    let viewModel = CustomerCenterViewModel(
      configuration: configuration,
      dependencies: deps,
      strings: .english
    )
    await viewModel.load()
    return viewModel
  }

  /// With a purchase history screen to fall back on, collapsing the inline list keeps the
  /// management screen scannable and the rest stays one tap away.
  @available(iOS 15.0, *)
  @Test("collapses the inline list when a purchase history screen can show the rest")
  func collapsesWhenHistoryIsReachable() async {
    let viewModel = await makeViewModel(nonSubscriptionCount: 5, showsPurchaseHistory: true)
    let view = ManagementScreenView(viewModel: viewModel)

    #expect(viewModel.purchases.count == 5)
    #expect(view.visibleOthers.count == 2)
  }

  /// Without one there is no "See all purchases" row, so anything past the cap would be
  /// unreachable rather than merely collapsed.
  @available(iOS 15.0, *)
  @Test("shows every purchase when purchase history is switched off")
  func showsAllWhenHistoryIsHidden() async {
    let viewModel = await makeViewModel(nonSubscriptionCount: 5, showsPurchaseHistory: false)
    let view = ManagementScreenView(viewModel: viewModel)

    #expect(view.visibleOthers.count == 5)
  }

  @available(iOS 15.0, *)
  @Test("a short list is unaffected either way")
  func shortListIsUntouched() async {
    for showsPurchaseHistory in [true, false] {
      let viewModel = await makeViewModel(nonSubscriptionCount: 1, showsPurchaseHistory: showsPurchaseHistory)
      let view = ManagementScreenView(viewModel: viewModel)
      #expect(view.visibleOthers.count == 1)
    }
  }
}
