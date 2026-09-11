//
//  DesignReviewSnapshots.swift
//
//
//  Created by Jordan Morgan on 26/08/2026.
//
//  Renders the Customer Center's screens across the customer states and configurations a
//  designer needs to review, and writes them to disk as PNGs.
//
//  Not part of the suite's verification — it asserts nothing about behaviour. It is dormant
//  unless `CUSTOMER_CENTER_SNAPSHOT_DIR` is set, which has to happen on the scheme: tick
//  `CUSTOMER_CENTER_SNAPSHOT_DIR` under Edit Scheme → Test → Arguments and point it at a
//  directory, then run `-only-testing:SuperwallKitTests/DesignReviewSnapshots`.
//
//  Setting it on the command line does not work, in either form — neither
//  `CUSTOMER_CENTER_SNAPSHOT_DIR=... xcodebuild test` nor xcodebuild's `TEST_RUNNER_` prefix
//  reaches the test process running in the simulator, and the suite silently skips.
//
//  The run ends by recording an issue naming the file count. That is the report, not a failure;
//  a passing run here would mean nothing was written.
//

import Testing
import Foundation
import SwiftUI
import UIKit
@testable import SuperwallKit

/// Where the PNGs go, or `nil` when the suite should stay dormant. A free function rather than a
/// static on the suite: a trait cannot reference the very type the `@Suite` macro is expanding.
private func customerCenterSnapshotDirectory() -> URL? {
  guard let raw = ProcessInfo.processInfo.environment["CUSTOMER_CENTER_SNAPSHOT_DIR"],
    !raw.isEmpty else {
    return nil
  }
  return URL(fileURLWithPath: (raw as NSString).expandingTildeInPath)
}

@Suite("Design review snapshots", .serialized, .enabled(if: customerCenterSnapshotDirectory() != nil))
@MainActor
struct DesignReviewSnapshots {
  static var outputDirectory: URL? { customerCenterSnapshotDirectory() }

  // MARK: - Fixtures

  private static let now = Date()
  private static let day: TimeInterval = 86_400

  private func subscription(
    productId: String = "monthly_pro",
    transactionId: String = "t1",
    purchaseDate: TimeInterval = -30,
    willRenew: Bool = true,
    isRevoked: Bool = false,
    isInGracePeriod: Bool = false,
    isInBillingRetryPeriod: Bool = false,
    isActive: Bool = true,
    expiresIn: TimeInterval? = 12,
    offerType: LatestSubscription.OfferType? = nil,
    groupId: String? = "group_pro",
    store: ProductStore = .appStore
  ) -> SubscriptionTransaction {
    SubscriptionTransaction(
      transactionId: transactionId,
      productId: productId,
      purchaseDate: Self.now.addingTimeInterval(purchaseDate * Self.day),
      willRenew: willRenew,
      isRevoked: isRevoked,
      isInGracePeriod: isInGracePeriod,
      isInBillingRetryPeriod: isInBillingRetryPeriod,
      isActive: isActive,
      expirationDate: expiresIn.map { Self.now.addingTimeInterval($0 * Self.day) },
      offerType: offerType,
      subscriptionGroupId: groupId,
      store: store
    )
  }

  private func nonSubscription(
    productId: String = "lifetime_pro",
    transactionId: String = "n1",
    purchaseDate: TimeInterval = -120,
    isConsumable: Bool = false,
    isRevoked: Bool = false
  ) -> NonSubscriptionTransaction {
    NonSubscriptionTransaction(
      transactionId: transactionId,
      productId: productId,
      purchaseDate: Self.now.addingTimeInterval(purchaseDate * Self.day),
      isConsumable: isConsumable,
      isRevoked: isRevoked,
      store: .appStore
    )
  }

  private var catalogue: [String: ProductDisplayInfo] {
    [
      "monthly_pro": .init(
        productId: "monthly_pro",
        title: "Pro Monthly",
        localizedPrice: "$9.99",
        price: 9.99,
        localizedPeriod: "month",
        subscriptionGroupId: "group_pro",
        isAutoRenewable: true
      ),
      "annual_pro": .init(
        productId: "annual_pro",
        title: "Pro Annual",
        localizedPrice: "$79.99",
        price: 79.99,
        localizedPeriod: "year",
        subscriptionGroupId: "group_pro",
        isAutoRenewable: true
      ),
      "coach_monthly": .init(
        productId: "coach_monthly",
        title: "Coaching Add-on",
        localizedPrice: "$4.99",
        price: 4.99,
        localizedPeriod: "month",
        subscriptionGroupId: "group_coach",
        isAutoRenewable: true
      ),
      "lifetime_pro": .init(
        productId: "lifetime_pro",
        title: "Lifetime Unlock",
        localizedPrice: "$149.99",
        price: 149.99,
        localizedPeriod: nil,
        subscriptionGroupId: nil,
        isAutoRenewable: false
      ),
      "coins_500": .init(
        productId: "coins_500",
        title: "500 Coins",
        localizedPrice: "$0.99",
        price: 0.99,
        localizedPeriod: nil,
        subscriptionGroupId: nil,
        isAutoRenewable: false
      ),
      // A web product as it will arrive once `/v1/products` carries a display name. Until it does,
      // a web purchase has no name and therefore no card — see `PurchasePresentationBuilder` — so
      // the unnamed shape isn't worth a screenshot: it renders as an empty management screen.
      "web_pro_monthly": .init(
        productId: "web_pro_monthly",
        title: "Pro",
        localizedPrice: "$12.99",
        price: 12.99,
        localizedPeriod: "month",
        subscriptionGroupId: nil,
        isAutoRenewable: true
      ),
      "extra_theme": .init(
        productId: "extra_theme",
        title: "Midnight Theme",
        localizedPrice: "$1.99",
        price: 1.99,
        localizedPeriod: nil,
        subscriptionGroupId: nil,
        isAutoRenewable: false
      )
    ]
  }

  /// The configuration a developer gets with no setup at all, plus a support email, since the
  /// contact-support row is hidden without one and the designer needs to see it.
  private func defaultConfiguration() -> CustomerCenterConfiguration {
    let configuration = CustomerCenterConfiguration.default
    configuration.support.email = "support@acme.com"
    return configuration
  }

  private func cancellationSurvey() -> CustomerCenterConfiguration.FeedbackSurvey {
    .init(
      id: "cancel_survey",
      title: "Why are you cancelling?",
      options: [
        .init(id: "too_expensive", title: "It's too expensive"),
        .init(id: "dont_use", title: "I don't use it enough"),
        .init(id: "missing_features", title: "Missing features I need"),
        .init(id: "switched", title: "I switched to something else"),
        .init(id: "other", title: "Another reason")
      ]
    )
  }

  // MARK: - Rendering

  private func makeViewModel(
    subscriptions: [SubscriptionTransaction] = [],
    nonSubscriptions: [NonSubscriptionTransaction] = [],
    entitlements: [Entitlement] = [],
    configuration: CustomerCenterConfiguration? = nil,
    environment: EnvironmentMock = EnvironmentMock(),
    familyShared: Set<String> = []
  ) async -> CustomerCenterViewModel {
    // Family sharing is the one gating input that isn't in `CustomerInfo` — it comes from a
    // StoreKit transaction lookup — so it has to be faked separately.
    let lookup = StoreKitTransactionLookupMock()
    lookup.familyShared = familyShared
    // `EnvironmentMock` defaults this to the Unix epoch, which renders as "December 31, 1969" in
    // Account details on nearly every screen. Harmless in a unit test, but in a design review it
    // reads as a bug and costs the room a conversation. Give it a plausible install date.
    var environment = environment
    if environment.originalDownloadDate == Date(timeIntervalSince1970: 0) {
      environment.originalDownloadDate = Self.now.addingTimeInterval(-400 * 24 * 60 * 60)
    }
    let (dependencies, _, _) = CustomerCenterDependencies.mock(
      info: CustomerInfo(
        subscriptions: subscriptions,
        nonSubscriptions: nonSubscriptions,
        entitlements: entitlements
      ),
      products: catalogue,
      environment: environment,
      lookup: lookup
    )
    let viewModel = CustomerCenterViewModel(
      configuration: configuration ?? defaultConfiguration(),
      dependencies: dependencies,
      strings: .english
    )
    await viewModel.load()
    return viewModel
  }

  /// Hosts `view` in a window at iPhone dimensions and writes a PNG.
  private func snapshot<V: View>(
    _ view: V,
    named name: String,
    colorScheme: ColorScheme,
    directory: URL
  ) {
    let host = UIHostingController(rootView: view.preferredColorScheme(colorScheme))
    host.overrideUserInterfaceStyle = colorScheme == .dark ? .dark : .light

    let window: UIWindow
    if let scene = UIApplication.sharedApplication?.connectedScenes.first as? UIWindowScene {
      window = UIWindow(windowScene: scene)
    } else {
      window = UIWindow(frame: UIScreen.main.bounds)
    }
    let size = window.bounds.size
    host.view.frame = CGRect(origin: .zero, size: size)
    window.overrideUserInterfaceStyle = host.overrideUserInterfaceStyle
    window.rootViewController = host
    window.makeKeyAndVisible()

    // Let SwiftUI settle: `.task`/`onAppear` work and List layout land a runloop turn or two after
    // the view is installed, and a capture taken too early shows an empty or half-laid-out screen.
    host.view.setNeedsLayout()
    host.view.layoutIfNeeded()
    for _ in 0..<8 {
      RunLoop.current.run(until: Date().addingTimeInterval(0.05))
    }
    host.view.layoutIfNeeded()

    // `layer.render` rather than `drawHierarchy`: this bundle runs with no window scene attached,
    // so there is no render server for `drawHierarchy` to snapshot and it yields a blank fill.
    let format = UIGraphicsImageRendererFormat()
    format.scale = 3
    let renderer = UIGraphicsImageRenderer(size: size, format: format)
    let image = renderer.image { context in
      window.layer.render(in: context.cgContext)
    }
    let suffix = colorScheme == .dark ? "dark" : "light"
    let url = directory.appendingPathComponent("\(name)-\(suffix).png")
    if let data = image.pngData() {
      try? data.write(to: url)
    }
    window.isHidden = true
  }

  private func capture(
    _ name: String,
    directory: URL,
    viewModel: CustomerCenterViewModel
  ) {
    for scheme in [ColorScheme.light, .dark] {
      snapshot(
        CustomerCenterView(viewModel: viewModel, navigationOptions: .default),
        named: name,
        colorScheme: scheme,
        directory: directory
      )
    }
  }

  /// Captures a screen the user drills into, wrapped in its own navigation so it renders with the
  /// title bar the designer would see.
  private func captureDetail<V: View>(
    _ name: String,
    directory: URL,
    viewModel: CustomerCenterViewModel,
    @ViewBuilder content: () -> V
  ) {
    let view = NavigationView { content() }
      .navigationViewStyle(.stack)
      .environment(\.customerCenterStrings, viewModel.strings)
      .environment(
        \.customerCenterTheme,
        CustomerCenterTheme(appearance: viewModel.configuration.appearance, colorScheme: .light)
      )
    for scheme in [ColorScheme.light, .dark] {
      snapshot(view, named: name, colorScheme: scheme, directory: directory)
    }
  }

  /// Captures the content of a `.sheet`. Deliberately not wrapped in a `NavigationView`: a page
  /// sheet has no bar unless its content supplies one, so wrapping it would paint a title bar
  /// production never shows — and hide the very thing the screenshot exists to reveal.
  private func captureSheet<V: View>(
    _ name: String,
    directory: URL,
    viewModel: CustomerCenterViewModel,
    @ViewBuilder content: () -> V
  ) {
    let view = content()
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color(uiColor: .systemBackground))
      .environment(\.customerCenterStrings, viewModel.strings)
    for scheme in [ColorScheme.light, .dark] {
      snapshot(view, named: name, colorScheme: scheme, directory: directory)
    }
  }

  // MARK: - The screens

  @available(iOS 15.0, *)
  @Test("render every Customer Center state for design review")
  func renderAll() async throws {
    let directory = try #require(Self.outputDirectory)
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    // 1. Nothing purchased — the empty state.
    capture("01-no-purchases", directory: directory, viewModel: await makeViewModel())

    // 2. One active auto-renewing subscription. Its row opens the detail screen, which is where
    //    the subscription's own actions live.
    capture(
      "02-active-subscription",
      directory: directory,
      viewModel: await makeViewModel(subscriptions: [subscription()])
    )

    // 3. Active, but the user has already cancelled — still entitled until the period ends.
    capture(
      "03-cancelled-still-active",
      directory: directory,
      viewModel: await makeViewModel(subscriptions: [subscription(willRenew: false, expiresIn: 9)])
    )

    // 4. Payment failed and Apple is retrying. The state most worth designing for.
    capture(
      "04-billing-retry",
      directory: directory,
      viewModel: await makeViewModel(
        subscriptions: [subscription(isInBillingRetryPeriod: true, expiresIn: 2)]
      )
    )

    // 5. In grace period — still entitled while Apple retries.
    capture(
      "05-grace-period",
      directory: directory,
      viewModel: await makeViewModel(
        subscriptions: [subscription(isInGracePeriod: true, expiresIn: 3)]
      )
    )

    // 6. Lapsed.
    capture(
      "06-expired-subscription",
      directory: directory,
      viewModel: await makeViewModel(
        subscriptions: [
          subscription(purchaseDate: -400, willRenew: false, isActive: false, expiresIn: -30)
        ]
      )
    )

    // 7. Refunded / revoked by Apple.
    capture(
      "07-revoked-subscription",
      directory: directory,
      viewModel: await makeViewModel(
        subscriptions: [subscription(isRevoked: true, isActive: false, expiresIn: -5)]
      )
    )

    // 8. Free trial.
    capture(
      "08-free-trial",
      directory: directory,
      viewModel: await makeViewModel(
        subscriptions: [subscription(purchaseDate: -3, expiresIn: 4, offerType: .trial)]
      )
    )

    // 9. Several subscriptions at once — the list layout, where each row drills in.
    capture(
      "09-multiple-subscriptions",
      directory: directory,
      viewModel: await makeViewModel(
        subscriptions: [
          subscription(),
          subscription(
            productId: "coach_monthly",
            transactionId: "t2",
            purchaseDate: -10,
            groupId: "group_coach"
          )
        ]
      )
    )

    // 10. A subscription plus one-off purchases.
    capture(
      "10-subscription-and-purchases",
      directory: directory,
      viewModel: await makeViewModel(
        subscriptions: [subscription()],
        nonSubscriptions: [
          nonSubscription(),
          nonSubscription(productId: "extra_theme", transactionId: "n2", purchaseDate: -60)
        ]
      )
    )

    // 11. Non-subscription purchases only.
    capture(
      "11-lifetime-only",
      directory: directory,
      viewModel: await makeViewModel(nonSubscriptions: [nonSubscription()])
    )

    // 12. A subscription alongside several one-off purchases, every one of them shown.
    let manyPurchases = await makeViewModel(
      subscriptions: [subscription()],
      nonSubscriptions: [
        nonSubscription(),
        nonSubscription(productId: "extra_theme", transactionId: "n2", purchaseDate: -60),
        nonSubscription(productId: "coins_500", transactionId: "n3", purchaseDate: -20, isConsumable: true),
        nonSubscription(productId: "coins_500", transactionId: "n4", purchaseDate: -8, isConsumable: true)
      ]
    )
    capture("12-many-purchases", directory: directory, viewModel: manyPurchases)

    // 14. The per-purchase detail screen, reached from the multi-subscription list.
    let multi = await makeViewModel(
      subscriptions: [
        subscription(),
        subscription(
          productId: "coach_monthly",
          transactionId: "t2",
          purchaseDate: -10,
          groupId: "group_coach"
        )
      ]
    )
    if let purchase = multi.purchases.first {
      captureDetail("14-purchase-detail", directory: directory, viewModel: multi) {
        PurchaseDetailScreenView(viewModel: multi, purchase: purchase)
      }
    }

    // 15. The cancellation survey sheet.
    let surveyConfiguration = defaultConfiguration()
    surveyConfiguration.managementScreen.paths = surveyConfiguration.managementScreen.paths.map { path in
      if path.type == .manageSubscription {
        path.survey = cancellationSurvey()
      }
      return path
    }
    let surveyModel = await makeViewModel(
      subscriptions: [subscription()],
      configuration: surveyConfiguration
    )
    if let purchase = surveyModel.purchases.first,
      let manage = surveyModel.paths(for: purchase).first(where: { $0.path.type == .manageSubscription }) {
      await surveyModel.select(manage, purchase: purchase)
      captureDetail("15-cancellation-survey", directory: directory, viewModel: surveyModel) {
        FeedbackSurveyView(viewModel: surveyModel)
      }
    }

    // 16. The "update your app" banner.
    let updateConfiguration = defaultConfiguration()
    updateConfiguration.support.shouldWarnToUpdate = true
    updateConfiguration.support.latestAppVersion = "2.0.0"
    capture(
      "16-update-banner",
      directory: directory,
      viewModel: await makeViewModel(
        subscriptions: [subscription()],
        configuration: updateConfiguration,
        environment: EnvironmentMock(appVersion: "1.0.0")
      )
    )

    // 17. The duplicate-subscription warning: subscribed on the App Store and on the web.
    let duplicateConfiguration = defaultConfiguration()
    duplicateConfiguration.warnsAboutDuplicateSubscriptions = true
    capture(
      "17-duplicate-subscription-warning",
      directory: directory,
      viewModel: await makeViewModel(
        subscriptions: [
          subscription(),
          subscription(
            productId: "annual_pro",
            transactionId: "t3",
            purchaseDate: -5,
            groupId: nil,
            store: .stripe
          )
        ],
        configuration: duplicateConfiguration
      )
    )

    // 18. No support email configured — contact support disappears.
    let noSupport = CustomerCenterConfiguration.default
    capture(
      "18-no-support-email",
      directory: directory,
      viewModel: await makeViewModel(
        subscriptions: [subscription()],
        configuration: noSupport
      )
    )

    // 19. Account details switched off — the most stripped-back screen.
    let minimal = defaultConfiguration()
    minimal.showsAccountDetails = false
    capture(
      "19-minimal-configuration",
      directory: directory,
      viewModel: await makeViewModel(subscriptions: [subscription()], configuration: minimal)
    )

    // 20. A branded accent colour, to check the theming hook.
    let branded = defaultConfiguration()
    branded.appearance = .init(
      accent: .init(light: UIColor.systemPurple, dark: UIColor.systemTeal)
    )
    capture(
      "20-custom-accent",
      directory: directory,
      viewModel: await makeViewModel(subscriptions: [subscription()], configuration: branded)
    )

    // 21. Restore in progress — the blocking overlay.
    let restoring = await makeViewModel()
    restoring.restoreState = .restoring
    capture("21-restore-in-progress", directory: directory, viewModel: restoring)

    // 22. Restore finished with nothing to restore.
    let restoreEmpty = await makeViewModel()
    restoreEmpty.restoreState = .notFound
    capture("22-restore-nothing-found", directory: directory, viewModel: restoreEmpty)

    // MARK: - Mixed stores and multiple groups

    let webManagementURL = URL(string: "https://acme.com/account")
    let webSubscription = subscription(
      productId: "web_pro_monthly",
      transactionId: "w1",
      purchaseDate: -20,
      expiresIn: 10,
      groupId: nil,
      store: .stripe
    )

    // 23. A web subscription on its own. No Change plan or Refund — both are App Store only —
    //     and the manage row points at the web management page instead.
    //
    // `EnvironmentMock` takes the URL directly; only `LiveEnvironment` reads it out of the
    // configuration. Set both, or this renders scenario 24's unconfigured screen instead.
    let webConfigured = defaultConfiguration()
    webConfigured.support.webManagementURL = webManagementURL
    capture(
      "23-web-subscription-only",
      directory: directory,
      viewModel: await makeViewModel(
        subscriptions: [webSubscription],
        configuration: webConfigured,
        environment: EnvironmentMock(webManagementURL: webManagementURL)
      )
    )

    // 24. The same customer with no management URL configured, which is what most apps will
    //     have on day one. The list itself is identical to 23 — the row stays put, because
    //     removing it would leave a paying customer with no way to manage anything — so the
    //     screenshot has to be what the tap produces, which is where the two diverge.
    let noWebURL = defaultConfiguration()
    noWebURL.support.webManagementURL = nil
    let unconfigured = await makeViewModel(
      subscriptions: [webSubscription],
      configuration: noWebURL,
      environment: EnvironmentMock(webManagementURL: nil)
    )
    captureSheet(
      "24-web-subscription-no-management-url",
      directory: directory,
      viewModel: unconfigured
    ) {
      Text(unconfigured.strings.string("customer_center_web_manage_unavailable")).padding()
    }

    // 25. App Store and web active at once — the case where the two stores sit side by side and
    //     the duplicate warning fires.
    let mixedStores = defaultConfiguration()
    mixedStores.warnsAboutDuplicateSubscriptions = true
    mixedStores.support.webManagementURL = webManagementURL
    let mixed = await makeViewModel(
      subscriptions: [subscription(), webSubscription],
      configuration: mixedStores,
      environment: EnvironmentMock(webManagementURL: webManagementURL)
    )
    capture("25-app-store-and-web", directory: directory, viewModel: mixed)

    // 26 & 27. The point of the mixed case: the same screen offers different actions per
    //          purchase, because what a store permits differs. Apple's sub can change plan and
    //          request a refund; the web one can only be managed on the web.
    if let appStorePurchase = mixed.purchases.first(where: { $0.store == .appStore }) {
      captureDetail("26-mixed-detail-app-store", directory: directory, viewModel: mixed) {
        PurchaseDetailScreenView(viewModel: mixed, purchase: appStorePurchase)
      }
    }
    if let webPurchase = mixed.purchases.first(where: { $0.store == .stripe }) {
      captureDetail("27-mixed-detail-web", directory: directory, viewModel: mixed) {
        PurchaseDetailScreenView(viewModel: mixed, purchase: webPurchase)
      }
    }

    // 28. Two App Store subscriptions in different subscription groups, drilled into one of
    //     them. Change plan is scoped to that subscription's own group — Apple's sheet takes a
    //     single group, so there is no combined plan picker to offer.
    let twoGroups = await makeViewModel(
      subscriptions: [
        subscription(),
        subscription(
          productId: "coach_monthly",
          transactionId: "t2",
          purchaseDate: -10,
          groupId: "group_coach"
        )
      ]
    )
    if let first = twoGroups.purchases.first {
      captureDetail("28-two-groups-detail", directory: directory, viewModel: twoGroups) {
        PurchaseDetailScreenView(viewModel: twoGroups, purchase: first)
      }
    }

    // 29. An entitlement with no transaction behind it — comped, or granted by hand. There is
    //     nothing to manage, so the management row is absent rather than pointing nowhere.
    capture(
      "29-comped-entitlement",
      directory: directory,
      viewModel: await makeViewModel(entitlements: [Entitlement(id: "pro", store: nil)])
    )

    // 30. Shared through Family Sharing. Cancel, refund and change plan all disappear: the
    //     purchase belongs to the organiser, not this customer.
    capture(
      "30-family-shared",
      directory: directory,
      viewModel: await makeViewModel(
        subscriptions: [subscription()],
        familyShared: ["monthly_pro"]
      )
    )

    let written = (try? FileManager.default.contentsOfDirectory(atPath: directory.path))?
      .filter { $0.hasSuffix(".png") }
      .count ?? 0
    Issue.record(Comment(rawValue: "WROTE \(written) PNGs to \(directory.path)"))
  }
}
