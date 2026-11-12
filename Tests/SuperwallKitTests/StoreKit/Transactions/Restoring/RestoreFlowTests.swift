//
//  RestoreFlowTests.swift
//  SuperwallKit
//
//  Created by Superwall on 06/11/2026.
//
// swiftlint:disable all

import Foundation
import StoreKit
import Testing
@testable import SuperwallKit

/// Records what restores cause, and restores with a result it's given.
private final class FakeRestoreContext: RestoreContext, @unchecked Sendable {
  let purchasingCoordinator: PurchasingCoordinator
  var hasExternalPurchaseController = false
  var isUsingStoreKit2 = true
  var isTestMode = false
  var testModeResult: RestorationResult?
  var paywallOptions = PaywallOptions()
  var restoreAccessURL: URL?
  var activeEntitlementIds: Set<String> = []
  var restorationResult: RestorationResult = .restored
  var restoreDurationNs: UInt64 = 0
  /// Runs during each StoreKit restore, before it returns.
  var duringStoreKitRestore: (() async -> Void)?

  private let lock = NSLock()
  private var events: [Trackable] = []
  private var alerts: [String] = []
  private var running = 0
  private var redeems = 0
  private(set) var mostRunningAtOnce = 0

  init(coordinator: PurchasingCoordinator) {
    purchasingCoordinator = coordinator
  }

  var trackedEvents: [Trackable] {
    lock.lock()
    defer { lock.unlock() }
    return events
  }

  var alertTitles: [String] {
    lock.lock()
    defer { lock.unlock() }
    return alerts
  }

  var redeemCount: Int {
    lock.lock()
    defer { lock.unlock() }
    return redeems
  }

  func entitlementIds(forProductId productId: String) -> Set<String> {
    return []
  }

  func track(_ event: Trackable) async {
    lock.lock()
    events.append(event)
    lock.unlock()
  }

  func restoreWithPurchaseController() async -> RestorationResult {
    return await restoreWithStoreKit()
  }

  func restoreWithStoreKit() async -> RestorationResult {
    lock.lock()
    running += 1
    mostRunningAtOnce = max(mostRunningAtOnce, running)
    lock.unlock()
    try? await Task.sleep(nanoseconds: restoreDurationNs)
    await duringStoreKitRestore?()
    lock.lock()
    running -= 1
    lock.unlock()
    return restorationResult
  }

  func restoreInTestMode() async -> RestorationResult? {
    return testModeResult
  }

  func presentAlert(title: String, message: String, closeActionTitle: String, source: RestoreSource) async {
    lock.lock()
    alerts.append(title)
    lock.unlock()
  }

  func redeemExistingWebEntitlements() {
    lock.lock()
    redeems += 1
    lock.unlock()
  }

  #if canImport(WebKit)
  func showLoading(on paywall: PaywallViewController) {}
  func notify(_ paywall: PaywallViewController, of message: PaywallMessage) {}
  func presentAlert(
    on paywall: PaywallViewController,
    title: String,
    message: String,
    actionTitle: String?,
    closeActionTitle: String,
    action: (() -> Void)?
  ) {}
  func open(_ url: URL) {}
  func dismiss(_ paywall: PaywallViewController, result: PaywallResult) async {}
  #endif
}

private final class NoTransactionsContext: PurchaseContext {
  let store = PurchaseStore(initial: PurchaseState())
  func deliver(_ result: PurchaseResult, to completion: @escaping PurchaseCompletion) {
    completion(result)
  }
  func makeStoreTransaction(from transaction: SK1Transaction) async -> StoreTransaction {
    fatalError("Not used")
  }
  func makeStoreTransaction(from transaction: SK2Transaction) async -> StoreTransaction {
    fatalError("Not used")
  }
  func latestTransaction(forProductId productId: String, since date: Date) async -> StoreTransaction? {
    return nil
  }
  func currentEntitlementTransaction(forProductId productId: String, since date: Date) async -> StoreTransaction? {
    return nil
  }
  func waitBeforeRetrying() async {}
}

private func makeFlow() -> (RestoreFlow, FakeRestoreContext) {
  let coordinator = PurchasingCoordinator(context: NoTransactionsContext())
  let context = FakeRestoreContext(coordinator: coordinator)
  return (RestoreFlow(context: context), context)
}

private func transactionEvents(_ events: [Trackable]) -> [InternalSuperwallEvent.Transaction] {
  return events.compactMap { $0 as? InternalSuperwallEvent.Transaction }
}

private func restoreStates(_ events: [Trackable]) -> [String] {
  return events.compactMap { event -> String? in
    guard let restore = event as? InternalSuperwallEvent.Restore else {
      return nil
    }
    switch restore.state {
    case .start:
      return "start"
    case .complete:
      return "complete"
    case .fail:
      return "fail"
    }
  }
}

@Suite("RestoreFlow")
struct RestoreFlowTests {
  @Test("a successful restore tracks its start, completion and the restore, then redeems")
  @MainActor
  func successfulRestore() async {
    let (flow, context) = makeFlow()
    context.activeEntitlementIds = ["pro"]

    let result = await flow.restore(.external)

    #expect(result == .restored)
    #expect(restoreStates(context.trackedEvents) == ["start", "complete"])
    #expect(transactionEvents(context.trackedEvents).count == 1)
    #expect(context.redeemCount == 1)
    #expect(context.alertTitles.isEmpty)
  }

  @Test("a restore that leaves no active entitlements fails and shows the failure alert")
  @MainActor
  func restoreWithoutEntitlements() async {
    let (flow, context) = makeFlow()

    let result = await flow.restore(.external)

    #expect(result == .restored)
    #expect(restoreStates(context.trackedEvents) == ["start", "fail"])
    #expect(context.alertTitles == [context.paywallOptions.restoreFailed.title])
    #expect(context.redeemCount == 0)
  }

  @Test("the failure alert can be left to the caller")
  @MainActor
  func failureAlertSuppressed() async {
    let (flow, context) = makeFlow()
    context.restorationResult = .failed(nil)

    _ = await flow.restore(.external, presentsFailureAlert: false)

    #expect(context.alertTitles.isEmpty)
  }

  @Test("with a purchase controller, the app's restore only restores through StoreKit")
  @MainActor
  func externalRestoreWithPurchaseController() async {
    let (flow, context) = makeFlow()
    context.hasExternalPurchaseController = true

    let result = await flow.restore(.external)

    #expect(result == .restored)
    #expect(context.trackedEvents.isEmpty)
  }

  @Test("test mode's result is returned without restoring through StoreKit")
  @MainActor
  func testModeRestore() async {
    let (flow, context) = makeFlow()
    context.testModeResult = .restored
    context.isTestMode = true

    let result = await flow.restore(.external)

    #expect(result == .restored)
    #expect(context.mostRunningAtOnce == 0)
    #expect(transactionEvents(context.trackedEvents).count == 1)
    #expect(context.redeemCount == 0)
  }

  @Test("restores asked for at the same time run one after the other")
  @MainActor
  func restoresRunOneAtATime() async {
    let (flow, context) = makeFlow()
    context.restoreDurationNs = 100_000_000
    context.activeEntitlementIds = ["pro"]

    async let first = flow.restore(.external)
    async let second = flow.restore(.external)
    async let third = flow.restore(.external)
    let results = await [first, second, third]

    #expect(results == [.restored, .restored, .restored])
    #expect(context.mostRunningAtOnce == 1)
  }

  @Test("a restore started from inside a restore runs straight away")
  @MainActor
  func nestedRestoreRunsInline() async {
    let (flow, context) = makeFlow()
    context.activeEntitlementIds = ["pro"]
    var nestedResult: RestorationResult?
    context.duringStoreKitRestore = { [weak context] in
      context?.duringStoreKitRestore = nil
      nestedResult = await flow.restore(.external)
    }

    let result = await flow.restore(.external)

    #expect(result == .restored)
    #expect(nestedResult == .restored)
  }

  @Test("a restore during a purchase is tracked with the purchase's product")
  func didRestoreDuringPurchase() async {
    let (flow, context) = makeFlow()
    let product = StoreProduct(sk1Product: MockSkProduct(productIdentifier: "product"))
    context.purchasingCoordinator.beginPurchase(of: product, source: .purchaseFunc(product), isFreeTrialAvailable: false)

    await flow.didRestore()

    let events = transactionEvents(context.trackedEvents)
    #expect(events.count == 1)
    #expect(events.first?.product?.productIdentifier == "product")
    #expect(events.first?.source == .external)
  }

  @Test("a restore without a source or purchase tracks nothing")
  func didRestoreWithoutSource() async {
    let (flow, context) = makeFlow()

    await flow.didRestore()

    #expect(context.trackedEvents.isEmpty)
    #expect(context.redeemCount == 0)
  }
}
