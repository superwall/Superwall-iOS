//
//  CustomerCenterDelegateAdapterTests.swift
//
//
//  Created by Jordan Morgan on 20/08/2026.
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
    func customerCenterShouldRestorePurchases() async -> Bool { restoreGateProceeds }
    func customerCenterDidSelectAction(_ action: CustomerCenterAction, for purchase: SubscriptionTransaction?) { selected.append(action) }
    func customerCenterDidCompleteSurvey(surveyId: String, optionId: String, action: CustomerCenterAction) {
      surveys.append((surveyId, optionId, action))
    }
    func customerCenterDidCompleteRefundRequest(productId: String, status: CustomerCenterRefundStatus) {
      refunds.append((productId, status))
    }
    func customerCenterDidDismiss() { dismissed += 1 }
  }

  @Test("forwards every callback to a Swift delegate")
  func forwardsSwift() async {
    let delegate = SwiftDelegate()
    let callbacks = CustomerCenterDelegateAdapter(swiftDelegate: delegate, objcDelegate: nil).makeCallbacks()
    let proceeded = await callbacks.shouldRestore?()
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

  final class ObjcDelegate: NSObject, CustomerCenterDelegateObjc {
    var answer: (@escaping (Bool) -> Void) -> Void = { $0(true) }
    func customerCenterShouldRestorePurchases(completion: @escaping (Bool) -> Void) { answer(completion) }
  }

  final class SilentObjcDelegate: NSObject, CustomerCenterDelegateObjc {}

  @Test("Objective-C: the first completion call wins and a second one is ignored")
  func objcCompletionCalledTwice() async {
    let delegate = ObjcDelegate()
    delegate.answer = { completion in
      completion(false)
      completion(true)
    }
    let callbacks = CustomerCenterDelegateAdapter(swiftDelegate: nil, objcDelegate: delegate).makeCallbacks()
    let proceeded = await callbacks.shouldRestore?()
    #expect(proceeded == false)
  }

  @Test("Objective-C: the restore waits for a completion called later, from another thread")
  func objcCompletionCalledLater() async {
    let delegate = ObjcDelegate()
    delegate.answer = { completion in
      DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) { completion(false) }
    }
    let callbacks = CustomerCenterDelegateAdapter(swiftDelegate: nil, objcDelegate: delegate).makeCallbacks()
    let proceeded = await callbacks.shouldRestore?()
    #expect(proceeded == false)
  }

  @Test("Objective-C: a delegate that doesn't implement the check leaves restores ungated")
  func objcWithoutRestoreCheck() {
    let delegate = SilentObjcDelegate()
    let callbacks = CustomerCenterDelegateAdapter(swiftDelegate: nil, objcDelegate: delegate).makeCallbacks()
    #expect(callbacks.shouldRestore == nil)
  }
}

