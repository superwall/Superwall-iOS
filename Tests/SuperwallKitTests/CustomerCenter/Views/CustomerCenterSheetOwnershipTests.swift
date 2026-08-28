//
//  CustomerCenterSheetOwnershipTests.swift
//
//
//  Created by Jordan Morgan on 28/08/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import SuperwallKit

/// When the host owns the navigation, the Customer Center's screens are separate hosting
/// controllers and every one of them applies the sheet modifiers. Only the screen the user is
/// actually looking at may present, or two controllers race for the same sheet.
@Suite("Customer Center sheet ownership")
@MainActor
struct CustomerCenterSheetOwnershipTests {
  @available(iOS 15.0, *)
  private func makeViewModel() -> CustomerCenterViewModel {
    let (deps, _, _) = CustomerCenterDependencies.mock(
      info: CustomerInfo(subscriptions: [], nonSubscriptions: [], entitlements: [])
    )
    return CustomerCenterViewModel(configuration: .default, dependencies: deps, strings: .english)
  }

  /// Reproduces the bindings a surface at `depth` sees, which is what decides whether it presents.
  @available(iOS 15.0, *)
  private func presents(depth: Int, viewModel: CustomerCenterViewModel) -> Bool {
    depth == viewModel.pushDepth
  }

  @available(iOS 15.0, *)
  @Test("only the topmost surface presents a sheet")
  func onlyTopmostPresents() {
    let viewModel = makeViewModel()
    viewModel.sheet = .refund(transactionId: 1, productId: "monthly")

    // Nothing pushed: the root owns it.
    #expect(presents(depth: 0, viewModel: viewModel))

    // A drill-down is pushed — the root must stand down or both try to present the same sheet.
    viewModel.pushDepth = 1
    #expect(!presents(depth: 0, viewModel: viewModel))
    #expect(presents(depth: 1, viewModel: viewModel))
  }

  /// The depth has to come back down, or the screen the user returns to can never present again.
  @available(iOS 15.0, *)
  @Test("popping the topmost surface hands presentation back")
  func poppingRestoresOwnership() {
    let viewModel = makeViewModel()
    viewModel.pushDepth = 1
    viewModel.pushDepth = 0
    #expect(presents(depth: 0, viewModel: viewModel))
  }

  /// Two screens popped at once are both removed, and UIKit doesn't promise which reports first.
  /// A shallower screen's restore must not be overwritten by a deeper one, or the depth is left
  /// above the surface the user is on and that surface is mute for the rest of the presentation.
  @available(iOS 15.0, *)
  @Test("restoring out of order does not strand the depth", arguments: [[1, 2], [2, 1]])
  func restoringOutOfOrderDoesNotStrand(removalOrder: [Int]) {
    let viewModel = makeViewModel()
    viewModel.pushDepth = 2

    // Each removed screen applies the navigator's rule: take the lowest depth reported.
    for depth in removalOrder {
      viewModel.pushDepth = min(viewModel.pushDepth, depth - 1)
    }

    #expect(viewModel.pushDepth == 0, "the root must be able to present again")
    #expect(presents(depth: 0, viewModel: viewModel))
  }
}
