//
//  WebSubscriptionPathTests.swift
//
//
//  Created by Jordan Morgan on 26/08/2026.
//

import Testing
import Foundation
@testable import SuperwallKit

@Suite("Web subscription paths")
@MainActor
struct WebSubscriptionPathTests {
  private let managementURL = URL(string: "https://superwall.app/manage")!

  private func webSubscription(store: ProductStore = .stripe) -> SubscriptionTransaction {
    SubscriptionTransaction(
      transactionId: "web_1",
      productId: "web_pro_monthly",
      purchaseDate: Date().addingTimeInterval(-30 * 86_400),
      willRenew: true,
      isRevoked: false,
      isInGracePeriod: false,
      isInBillingRetryPeriod: false,
      isActive: true,
      expirationDate: Date().addingTimeInterval(12 * 86_400),
      subscriptionGroupId: nil,
      store: store
    )
  }

  private func makeViewModel(
    store: ProductStore = .stripe,
    webManagementURL: URL?,
    survey: CustomerCenterConfiguration.FeedbackSurvey? = nil
  ) async -> CustomerCenterViewModel {
    let (deps, _, _) = CustomerCenterDependencies.mock(
      info: CustomerInfo(
        subscriptions: [webSubscription(store: store)],
        nonSubscriptions: [],
        entitlements: []
      ),
      environment: EnvironmentMock(webManagementURL: webManagementURL)
    )
    let configuration = CustomerCenterConfiguration.default
    configuration.support.webManagementURL = webManagementURL
    if let survey {
      for path in configuration.managementScreen.paths where path.type == .manageSubscription {
        path.survey = survey
      }
    }
    let viewModel = CustomerCenterViewModel(
      configuration: configuration,
      dependencies: deps,
      strings: .english
    )
    await viewModel.load()
    return viewModel
  }

  private func managePath(_ viewModel: CustomerCenterViewModel) -> ResolvedPath? {
    let purchase = viewModel.purchases.first
    return viewModel.paths(for: purchase).first { $0.path.type == .manageSubscription }
  }

  // MARK: - Only one row, and it goes to the management page

  @available(iOS 15.0, *)
  @Test("a web subscriber gets the management row and nothing App Store-only")
  func webSubscriberSeesOneManagementRow() async {
    let viewModel = await makeViewModel(webManagementURL: managementURL)
    let purchase = viewModel.purchases.first
    let types = viewModel.paths(for: purchase).map(\.path.type)

    #expect(types.contains(.manageSubscription))
    #expect(!types.contains { if case .changePlan = $0 { return true } else { return false } })
    #expect(!types.contains { if case .refund = $0 { return true } else { return false } })
    #expect(managePath(viewModel)?.destination == .webManage(managementURL))
  }

  @available(iOS 15.0, *)
  @Test("the management row survives a missing management URL", arguments: [
    ProductStore.stripe, .paddle, .superwall
  ])
  func rowRemainsWithoutAManagementURL(store: ProductStore) async {
    let viewModel = await makeViewModel(store: store, webManagementURL: nil)
    // Without this the row vanishes and a paying customer has no way to manage their subscription.
    #expect(managePath(viewModel)?.destination == .webManageUnavailable)
  }

  @available(iOS 15.0, *)
  @Test("tapping the row without a URL explains where to find the link")
  func unavailableRowShowsTheBlurb() async {
    let viewModel = await makeViewModel(webManagementURL: nil)
    let resolved = try? #require(managePath(viewModel))
    guard let resolved else { return }

    await viewModel.select(resolved, purchase: viewModel.purchases.first)
    #expect(viewModel.sheet == .webManageUnavailable)
  }

  @available(iOS 15.0, *)
  @Test("tapping the row with a URL opens the management page")
  func availableRowOpensTheManagementPage() async {
    let viewModel = await makeViewModel(webManagementURL: managementURL)
    let resolved = try? #require(managePath(viewModel))
    guard let resolved else { return }

    await viewModel.select(resolved, purchase: viewModel.purchases.first)
    #expect(viewModel.sheet == .safari(managementURL))
  }

  // MARK: - Surveys don't belong on a web flow

  /// The survey gates an action. On a web flow that action leaves the app — or, with no URL, can't
  /// happen at all — so asking the question here collects an answer for something we never see
  /// the outcome of.
  @available(iOS 15.0, *)
  @Test("no survey is shown before handing off to the web", arguments: [true, false])
  func webFlowsSkipTheSurvey(hasManagementURL: Bool) async {
    let survey = CustomerCenterConfiguration.FeedbackSurvey(
      id: "cancel_survey",
      title: "Why are you cancelling?",
      options: [.init(id: "too_expensive", title: "Too expensive")]
    )
    let viewModel = await makeViewModel(
      webManagementURL: hasManagementURL ? managementURL : nil,
      survey: survey
    )
    let resolved = try? #require(managePath(viewModel))
    guard let resolved else { return }

    await viewModel.select(resolved, purchase: viewModel.purchases.first)

    #expect(viewModel.pendingSurvey == nil)
    if case .survey = viewModel.sheet {
      Issue.record("a web flow should not present the survey")
    }
  }

  // MARK: - Labelling

  @available(iOS 15.0, *)
  @Test("web management destinations are labelled as managing, not cancelling")
  func webDestinationsAreLabelledAsManagement() {
    #expect(ResolvedPathDestination.webManage(managementURL).isWebManagement)
    #expect(ResolvedPathDestination.webManageUnavailable.isWebManagement)
    #expect(!ResolvedPathDestination.appleManageSheet(subscriptionGroupId: "g").isWebManagement)
    #expect(!ResolvedPathDestination.restore.isWebManagement)

    // The label the row actually renders differs between the two, which is the point.
    let strings = CustomerCenterStrings.english
    #expect(strings.string("customer_center_path_manage_subscription") == "Cancel subscription")
    #expect(strings.string("customer_center_path_manage_subscription_web") == "Manage subscription")
  }
}
