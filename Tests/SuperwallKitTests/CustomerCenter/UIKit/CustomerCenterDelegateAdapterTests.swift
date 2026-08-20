//
//  CustomerCenterDelegateAdapterTests.swift
//
//
//  Created by Claude on 20/08/2026.
//

import Testing
import Foundation
@testable import SuperwallKit

@Suite("CustomerCenterDelegateAdapter")
@MainActor
struct CustomerCenterDelegateAdapterTests {
  final class SwiftDelegate: CustomerCenterDelegate {
    var restoreGateProceeds = true
    var selected: [CustomerCenterAction] = []
    var surveys: [(String, String, CustomerCenterAction)] = []
    var refunds: [(String, CustomerCenterRefundStatus)] = []
    var dismissed = 0
    func customerCenter(shouldRestorePurchases resume: @escaping (Bool) -> Void) { resume(restoreGateProceeds) }
    func customerCenter(didSelect action: CustomerCenterAction, for purchase: SubscriptionTransaction?) { selected.append(action) }
    func customerCenter(didCompleteSurvey surveyId: String, optionId: String, for action: CustomerCenterAction) {
      surveys.append((surveyId, optionId, action))
    }
    func customerCenter(didCompleteRefundRequestFor productId: String, status: CustomerCenterRefundStatus) {
      refunds.append((productId, status))
    }
    func customerCenterDidDismiss() { dismissed += 1 }
  }

  @Test("forwards every callback to a Swift delegate")
  func forwardsSwift() async {
    let delegate = SwiftDelegate()
    let callbacks = CustomerCenterDelegateAdapter(swiftDelegate: delegate, objcDelegate: nil).makeCallbacks()
    var proceeded: Bool?
    callbacks.shouldRestore?({ proceeded = $0 })
    #expect(proceeded == true)
    callbacks.didSelectAction?(.refund, nil)
    callbacks.didCompleteSurvey?("s", "o", .manageSubscription)
    callbacks.didCompleteRefund?("p", .success)
    callbacks.didDismiss?()
    #expect(delegate.selected == [.refund])
    #expect(delegate.surveys.first?.1 == "o")
    #expect(delegate.refunds.first?.1 == .success)
    #expect(delegate.dismissed == 1)
  }

  @Test("no delegate: shouldRestore is nil so the view model proceeds")
  func noDelegate() {
    let callbacks = CustomerCenterDelegateAdapter(swiftDelegate: nil, objcDelegate: nil).makeCallbacks()
    #expect(callbacks.shouldRestore == nil)
  }
}
