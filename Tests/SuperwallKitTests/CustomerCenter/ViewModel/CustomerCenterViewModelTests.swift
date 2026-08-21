//
//  CustomerCenterViewModelTests.swift
//
//
//  Created by Jordan Morgan on 20/08/2026.
//

import Testing
import Foundation
@testable import SuperwallKit

@Suite("CustomerCenterViewModel")
@MainActor
struct CustomerCenterViewModelTests {
  let now = Date(timeIntervalSince1970: 1_700_000_000)
  let monthly = ProductDisplayInfo(productId: "monthly", title: "Monthly", localizedPrice: "$9.99", price: 9.99,
                                   localizedPeriod: "month", subscriptionGroupId: "g1", isAutoRenewable: true)

  func sub(store: ProductStore = .appStore, willRenew: Bool = true) -> SubscriptionTransaction {
    SubscriptionTransaction(transactionId: "t", productId: "monthly", purchaseDate: now.addingTimeInterval(-86_400), willRenew: willRenew,
      isRevoked: false, isInGracePeriod: false, isInBillingRetryPeriod: false, isActive: true,
      expirationDate: now.addingTimeInterval(86_400), offerType: nil, subscriptionGroupId: "g1", store: store)
  }

  func info(_ subs: [SubscriptionTransaction]) -> CustomerInfo { CustomerInfo(subscriptions: subs, nonSubscriptions: [], entitlements: []) }

  func make(info: CustomerInfo, config: CustomerCenterConfiguration = .default, env: EnvironmentMock = EnvironmentMock(),
            restorer: RestorerMock = RestorerMock(), opener: URLOpenerMock = URLOpenerMock(), tracker: EventTrackerMock = EventTrackerMock(),
            lookup: StoreKitTransactionLookupMock = StoreKitTransactionLookupMock())
  -> (CustomerCenterViewModel, CustomerInfoProviderMock, ProductsProviderMock) {
    let (deps, infoMock, productsMock) = CustomerCenterDependencies.mock(info: info, products: ["monthly": monthly], environment: env,
                                                                        restorer: restorer, urlOpener: opener, tracker: tracker, lookup: lookup)
    let vm = CustomerCenterViewModel(configuration: config, dependencies: deps, strings: .english, isChangePlanSheetAvailable: true)
    return (vm, infoMock, productsMock)
  }

  @Test("load: fetches fresh info + products, picks management screen, tracks open")
  func loadManagement() async {
    let tracker = EventTrackerMock()
    let (vm, infoMock, productsMock) = make(info: info([sub()]), tracker: tracker)
    await vm.load()
    #expect(infoMock.fetchCount == 1)
    #expect(productsMock.requested == ["monthly"])
    #expect(vm.state == .management)
    #expect(vm.purchases.map(\.id) == ["monthly"])
    if case .customerCenterOpen(let screen) = tracker.events.first {
      #expect(screen == "management")
    } else {
      Issue.record("expected a customerCenterOpen event")
    }
  }

  @Test("load: no purchases → noActive")
  func loadNoActive() async {
    let (vm, _, _) = make(info: info([]))
    await vm.load()
    #expect(vm.state == .noActive)
  }

  @Test("update banner only when latestAppVersion is newer and warn enabled")
  func updateBanner() async {
    let config = CustomerCenterConfiguration.default
    config.support.latestAppVersion = "2.0.0"
    let (vm, _, _) = make(info: info([sub()]), config: config, env: EnvironmentMock(appVersion: "1.0.0"))
    await vm.load()
    #expect(vm.showsUpdateBanner)
    vm.continueAfterUpdateWarning()
    #expect(!vm.showsUpdateBanner)
    config.support.shouldWarnToUpdate = false
    let (vm2, _, _) = make(info: info([sub()]), config: config, env: EnvironmentMock(appVersion: "1.0.0"))
    await vm2.load()
    #expect(!vm2.showsUpdateBanner)
  }

  @Test("duplicate banner when App Store + web subs both active")
  func duplicateBanner() async {
    let (vm, _, _) = make(info: info([sub(), sub(store: .stripe)]))
    await vm.load()
    #expect(vm.showsDuplicateBanner)
  }

  @Test("selecting a path with a survey: stores pending survey, presents sheet, no action yet")
  func surveyFlow() async {
    let tracker = EventTrackerMock()
    let (vm, _, _) = make(info: info([sub()]), tracker: tracker)
    await vm.load()
    let purchase = vm.purchases[0]
    let manage = vm.paths(for: purchase).first { $0.path.id == "manage_subscription" }!
    var selected: [CustomerCenterAction] = []
    vm.callbacks.didSelectAction = { action, _ in selected.append(action) }
    var survey: (String, String, CustomerCenterAction)?
    vm.callbacks.didCompleteSurvey = { survey = ($0, $1, $2) }

    await vm.select(manage, purchase: purchase)
    #expect(selected == [.manageSubscription])
    #expect(vm.sheet == .survey(pathId: "manage_subscription"))
    let hasActionEvent = tracker.events.contains { event in
      if case .customerCenterAction(let action, let pathId, let productId) = event {
        return action == .manageSubscription && pathId == "manage_subscription" && productId == "monthly"
      }
      return false
    }
    #expect(hasActionEvent)

    await vm.answerSurvey(optionId: "too_expensive")
    #expect(survey?.0 == "cancel_survey" && survey?.1 == "too_expensive" && survey?.2 == .manageSubscription)
    let hasSurveyEvent = tracker.events.contains { event in
      if case .customerCenterSurveyResponse(let surveyId, let optionId, let action, let pathId, let productId) = event {
        return surveyId == "cancel_survey" && optionId == "too_expensive" && action == .manageSubscription
          && pathId == "manage_subscription" && productId == "monthly"
      }
      return false
    }
    #expect(hasSurveyEvent)
    // The follow-up action is deferred: presenting the next sheet while the survey sheet is
    // still animating out is silently dropped on iOS 15/16.
    #expect(vm.sheet == nil)

    await vm.sheetDidDismiss()
    #expect(vm.sheet == .manageSubscriptions(groupId: "g1"))
  }

  @Test("cancelling the survey drops the pending action so a later dismissal performs nothing")
  func cancelSurveyDropsPendingAction() async {
    let (vm, _, _) = make(info: info([sub()]))
    await vm.load()
    let purchase = vm.purchases[0]
    let manage = vm.paths(for: purchase).first { $0.path.id == "manage_subscription" }!
    await vm.select(manage, purchase: purchase)
    #expect(vm.sheet == .survey(pathId: "manage_subscription"))

    vm.cancelSurvey()
    #expect(vm.pendingSurvey == nil)
    #expect(vm.sheet == nil)

    await vm.sheetDidDismiss()
    #expect(vm.sheet == nil)
  }

  @Test("restore: gate can cancel; success/notFound states; tracks via Superwall restore events (not duplicated here)")
  func restoreFlow() async {
    let restorer = RestorerMock()
    let (vm, _, _) = make(info: info([]), restorer: restorer)
    await vm.load()
    vm.callbacks.shouldRestore = { resume in resume(false) }
    await vm.performRestore()
    #expect(restorer.calls == 0)
    #expect(vm.restoreState == .idle)

    vm.callbacks.shouldRestore = nil
    await vm.performRestore()
    #expect(restorer.calls == 1)
    #expect(vm.restoreState == .notFound)   // info still has no purchases

    let (vm2, infoMock, _) = make(info: info([]), restorer: restorer)
    await vm2.load()
    infoMock.subject.value = info([sub()])
    await vm2.performRestore()
    #expect(vm2.restoreState == .restored)
  }

  @Test("restore: entitlement-only info (no local transactions) still counts as a purchase")
  func restoreFlowEntitlementOnly() async {
    let restorer = RestorerMock()
    let (vm, infoMock, _) = make(info: info([]), restorer: restorer)
    await vm.load()
    #expect(vm.state == .noActive)
    let entitlementOnlyInfo = CustomerInfo(subscriptions: [], nonSubscriptions: [], entitlements: [Entitlement(id: "premium")])
    infoMock.subject.value = entitlementOnlyInfo
    await vm.performRestore()
    #expect(vm.restoreState == .restored)
    #expect(vm.state == .management)
  }

  @Test("refund: select opens refund sheet with looked-up transaction id; finish records result + event + callback")
  func refundFlow() async {
    let lookup = StoreKitTransactionLookupMock(); lookup.transactionIDs["monthly"] = 42
    let tracker = EventTrackerMock()
    let (vm, _, _) = make(info: info([sub()]), tracker: tracker, lookup: lookup)
    await vm.load()
    let purchase = vm.purchases[0]
    let refund = vm.paths(for: purchase).first { $0.path.id == "refund" }!
    await vm.select(refund, purchase: purchase)
    #expect(vm.sheet == .refund(transactionId: 42, productId: "monthly"))
    var completed: (String, CustomerCenterRefundStatus)?
    vm.callbacks.didCompleteRefund = { completed = ($0, $1) }
    await vm.refundSheetDidFinish(productId: "monthly", status: .success)
    #expect(completed?.1 == .success)
    #expect(vm.refundResult?.status == .success)
    let hasRefundEvent = tracker.events.contains { event in
      if case .customerCenterRefundRequest(let productId, let status) = event {
        return productId == "monthly" && status == .success
      }
      return false
    }
    #expect(hasRefundEvent)
  }

  @Test("url external → opener; url inApp → safari sheet; custom → callback only; contactSupport → mailto")
  func urlCustomSupport() async {
    let opener = URLOpenerMock()
    let config = CustomerCenterConfiguration.default
    config.support.email = "help@app.com"
    let ext = URL(string: "https://a.b/ext")!, inApp = URL(string: "https://a.b/in")!
    config.managementScreen.paths += [
      .init(id: "ext", type: .url(ext, openMethod: .external)),
      .init(id: "in", type: .url(inApp, openMethod: .inApp)),
      .init(id: "c", type: .custom(identifier: "delete"))
    ]
    let (vm, _, _) = make(info: info([sub()]), config: config, opener: opener)
    await vm.load()
    var selected: [CustomerCenterAction] = []
    vm.callbacks.didSelectAction = { action, _ in selected.append(action) }
    let paths = vm.paths(for: nil)
    await vm.select(paths.first { $0.id == "ext" }!, purchase: nil)
    #expect(opener.opened == [ext])
    await vm.select(paths.first { $0.id == "in" }!, purchase: nil)
    #expect(vm.sheet == .safari(inApp))
    await vm.select(paths.first { $0.id == "c" }!, purchase: nil)
    #expect(selected.last == .custom(identifier: "delete"))
    await vm.select(paths.first { $0.id == "contact_support" }!, purchase: nil)
    #expect(opener.opened.last?.scheme == "mailto")
  }

  @Test("web sub manage → safari sheet with web management URL")
  func webManage() async {
    let url = URL(string: "https://x.superwall.app/manage")!
    let (vm, _, _) = make(info: info([sub(store: .stripe)]), env: EnvironmentMock(webManagementURL: url))
    await vm.load()
    let purchase = vm.purchases[0]
    let manage = vm.paths(for: purchase).first { $0.path.id == "manage_subscription" }!
    vm.callbacks.didSelectAction = nil
    // default manage path has a survey; answer it, then let the survey sheet finish dismissing
    // so the deferred follow-up action runs
    await vm.select(manage, purchase: purchase)
    await vm.answerSurvey(optionId: "dont_use")
    #expect(vm.sheet == nil)
    await vm.sheetDidDismiss()
    #expect(vm.sheet == .safari(url))
  }

  // MARK: - Contact support visibility

  @Test("contact support row shows even when canOpenURL is false; tap falls back to the address sheet")
  func contactSupportVisibleWithoutCanOpen() async {
    // On device `canOpenURL("mailto:")` is false unless the host app declares `mailto` in
    // `LSApplicationQueriesSchemes`, so visibility must not depend on it.
    let opener = URLOpenerMock()
    opener.openable = false
    let config = CustomerCenterConfiguration.default
    config.support.email = "help@app.com"
    let (vm, _, _) = make(info: info([sub()]), config: config, opener: opener)
    await vm.load()

    let contact = vm.paths(for: nil).first { $0.path.id == "contact_support" }
    #expect(contact != nil)

    await vm.select(contact!, purchase: nil)
    #expect(opener.opened.isEmpty)
    #expect(vm.sheet == .noMailApp(email: "help@app.com"))
  }

  @Test("contact support row is hidden when no support email is configured")
  func contactSupportHiddenWithoutEmail() async {
    let (vm, _, _) = make(info: info([sub()]))   // default config carries no support email
    await vm.load()
    #expect(!vm.paths(for: nil).contains { $0.path.id == "contact_support" })
  }

  // MARK: - Restore availability

  @Test("management screen still offers restore alongside a single subscription; detail screen doesn't")
  func managementPathsIncludeRestore() async {
    let (vm, _, _) = make(info: info([sub()]))
    await vm.load()
    let purchase = vm.purchases[0]
    #expect(vm.paths(for: purchase).map(\.destination).contains(.restore))
    #expect(!vm.paths(for: purchase, isScreenLevel: false).map(\.destination).contains(.restore))
  }

  // MARK: - Receipt refresh on store-sheet dismissal

  @Test("change-plan sheet dismissal reloads from receipts rather than the cache")
  func changePlanDismissalRefreshesReceipts() async {
    let (vm, infoMock, _) = make(info: info([sub()]))
    await vm.load()
    let purchase = vm.purchases[0]
    let change = vm.paths(for: purchase).first { $0.path.id == "change_plan" }!
    await vm.select(change, purchase: purchase)
    #expect(vm.sheet == .changePlan(groupId: "g1", productIds: nil))

    await vm.sheetDidDismiss()
    #expect(infoMock.didRefreshReceipts)
  }

  @Test("manage-subscriptions dismissal refreshes receipts; a plain sheet dismissal does not")
  func manageSubscriptionsDismissalRefreshesReceipts() async {
    let (vm, infoMock, _) = make(info: info([sub()]))
    await vm.load()
    let purchase = vm.purchases[0]
    let manage = vm.paths(for: purchase).first { $0.path.id == "manage_subscription" }!
    await vm.select(manage, purchase: purchase)
    await vm.answerSurvey(optionId: "too_expensive")

    // Dismissing the *survey* sheet performs the deferred action but needs no receipt reload.
    await vm.sheetDidDismiss()
    #expect(vm.sheet == .manageSubscriptions(groupId: "g1"))
    #expect(!infoMock.didRefreshReceipts)

    // Dismissing Apple's manage-subscriptions sheet does: cancelling auto-renew there emits no
    // `Transaction.updates`, so a cached read would miss it.
    await vm.sheetDidDismiss()
    #expect(infoMock.didRefreshReceipts)
  }

  // MARK: - Embedded navigation

  @Test("navigating within the Customer Center is not treated as a dismissal")
  func navigationWithinCustomerCenterIsNotDismissal() async {
    let (vm, _, _) = make(info: info([sub()]))
    await vm.load()
    var dismissed = false
    vm.callbacks.didDismiss = { dismissed = true }

    // Embedded mode: pushing the detail/history screen removes the root view from the hierarchy.
    vm.isNavigatingWithinCustomerCenter = true
    vm.rootViewDidDisappear()
    try? await Task.sleep(nanoseconds: 50_000_000)
    #expect(!dismissed)

    // A real disappearance still dismisses.
    vm.isNavigatingWithinCustomerCenter = false
    vm.rootViewDidDisappear()
    try? await Task.sleep(nanoseconds: 50_000_000)
    #expect(dismissed)
  }

  @Test("dismiss tracks close and calls back; publisher updates re-render")
  func dismissAndPublisher() async {
    let tracker = EventTrackerMock()
    let (vm, infoMock, _) = make(info: info([]), tracker: tracker)
    await vm.load()
    #expect(vm.state == .noActive)
    infoMock.subject.value = info([sub()])
    try? await Task.sleep(nanoseconds: 100_000_000)
    #expect(vm.state == .management)
    var dismissed = false
    vm.callbacks.didDismiss = { dismissed = true }
    vm.dismiss()
    try? await Task.sleep(nanoseconds: 50_000_000)
    #expect(dismissed)
    let hasCloseEvent: Bool
    if case .customerCenterClose = tracker.events.last {
      hasCloseEvent = true
    } else {
      hasCloseEvent = false
    }
    #expect(hasCloseEvent)
  }
}
