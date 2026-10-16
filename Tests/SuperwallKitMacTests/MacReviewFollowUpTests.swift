// swiftlint:disable all
#if os(macOS)
import AppKit
import SwiftUI
import Testing
@testable import SuperwallKit

@Suite(.serialized)
@MainActor
struct CustomerCenterMacManagementTests {
  private let managementURL = URL(string: "https://superwall.app/manage")!

  private func makeViewModel() async -> (CustomerCenterViewModel, CustomerInfoProviderMock, URLOpenerMock) {
    let subscription = SubscriptionTransaction(
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
      store: .stripe
    )
    let opener = URLOpenerMock()
    let (deps, info, _) = CustomerCenterDependencies.mock(
      info: CustomerInfo(subscriptions: [subscription], nonSubscriptions: [], entitlements: []),
      environment: EnvironmentMock(webManagementURL: managementURL),
      urlOpener: opener
    )
    let configuration = CustomerCenterConfiguration.default
    configuration.support.webManagementURL = managementURL
    let viewModel = CustomerCenterViewModel(
      configuration: configuration,
      dependencies: deps,
      strings: .english
    )
    await viewModel.load()
    return (viewModel, info, opener)
  }

  private func managePath(_ viewModel: CustomerCenterViewModel) -> ResolvedPath? {
    viewModel.paths(for: viewModel.purchases.first).first { $0.path.type == .manageSubscription }
  }

  @Test
  func returningFromTheAppStoreReadsReceiptsAgain() async throws {
    let (viewModel, info, opener) = await makeViewModel()
    let web = try #require(managePath(viewModel))
    // Skip the cancellation survey, which App Store management asks first.
    web.path.survey = nil
    let appStore = ResolvedPath(path: web.path, destination: .appleManageSheet(subscriptionGroupId: "g1"))

    await viewModel.select(appStore, purchase: viewModel.purchases.first)
    #expect(opener.opened == [CustomerCenterViewModel.appStoreSubscriptionsURL])
    #expect(info.refreshReceiptsCount == 0)

    await viewModel.appDidBecomeActive()
    #expect(info.refreshReceiptsCount == 1)

    // Only the return from that visit refreshes.
    await viewModel.appDidBecomeActive()
    #expect(info.refreshReceiptsCount == 1)
  }

  @Test
  func returningFromTheWebManagementPageFetchesCustomerInfoAgain() async throws {
    let (viewModel, info, opener) = await makeViewModel()
    let web = try #require(managePath(viewModel))
    let fetchesBefore = info.fetchCount

    await viewModel.select(web, purchase: viewModel.purchases.first)
    #expect(opener.opened == [managementURL])

    await viewModel.appDidBecomeActive()
    #expect(info.fetchCount == fetchesBefore + 1)
    #expect(info.refreshReceiptsCount == 0)
  }
}

@Suite
struct MacMicrophonePermissionTests {
  @Test
  func microphonePermissionIsSupported() {
    #expect(PermissionHandler().checkMicrophonePermission() != .unsupported)
  }
}

@Suite(.serialized)
@MainActor
struct TestModeSheetNoShowTests {
  private func makeWindow() -> NSWindow {
    _ = NSApplication.shared
    let window = NSWindow(contentViewController: NSViewController.blank())
    window.isReleasedWhenClosed = false
    window.setContentSize(NSSize(width: 600, height: 500))
    window.orderFront(nil)
    return window
  }

  @Test
  func sheetThatNeverShowsIsCancelled() async throws {
    let window = makeWindow()
    defer { window.close() }
    // A window shows one sheet at a time, so the test mode sheet waits behind this one.
    let blocker = NSViewController.blank()
    blocker.preferredContentSize = CGSize(width: 200, height: 100)
    window.contentViewController?.presentAsSheet(blocker)
    try await Task.sleep(nanoseconds: 300_000_000)

    var cancellations = 0
    TestModeSheetPresenter.present(
      size: CGSize(width: 300, height: 200),
      on: window.contentViewController,
      noShowTimeout: 0.3,
      onCancel: { cancellations += 1 }
    ) { _ in Text("Test Mode").frame(width: 300, height: 200) }
    try await Task.sleep(nanoseconds: 800_000_000)
    #expect(cancellations == 1)

    window.contentViewController?.dismiss(blocker)
    try await Task.sleep(nanoseconds: 500_000_000)
    #expect(cancellations == 1)
  }

  @Test
  func sheetThatShowsIsNotCancelled() async throws {
    let window = makeWindow()
    defer { window.close() }
    var cancellations = 0
    var finish: (() -> Bool)?
    TestModeSheetPresenter.present(
      size: CGSize(width: 300, height: 200),
      on: window.contentViewController,
      noShowTimeout: 0.3,
      onCancel: { cancellations += 1 }
    ) { close in
      finish = close
      return Text("Test Mode").frame(width: 300, height: 200)
    }
    try await Task.sleep(nanoseconds: 800_000_000)
    #expect(cancellations == 0)
    #expect(finish?() == true)
  }
}
#endif
