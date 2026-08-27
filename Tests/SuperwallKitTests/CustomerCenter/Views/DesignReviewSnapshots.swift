//
//  DesignReviewSnapshots.swift
//
//
//  Created by Jordan Morgan on 26/08/2026.
//
//  Renders the Customer Center's screens across the customer states and configurations a
//  designer needs to review, and writes them to disk as PNGs.
//
//  Not part of the suite's verification — it asserts nothing about behaviour. It is disabled by
//  default and only runs when `CUSTOMER_CENTER_SNAPSHOT_DIR` is set:
//
//      CUSTOMER_CENTER_SNAPSHOT_DIR=~/Desktop/customer-center-screens \
//        xcodebuild test -only-testing:SuperwallKitTests/DesignReviewSnapshots ...
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
    environment: EnvironmentMock = EnvironmentMock()
  ) async -> CustomerCenterViewModel {
    let (dependencies, _, _) = CustomerCenterDependencies.mock(
      info: CustomerInfo(
        subscriptions: subscriptions,
        nonSubscriptions: nonSubscriptions,
        entitlements: entitlements
      ),
      products: catalogue,
      environment: environment
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

  // MARK: - The screens

  @available(iOS 15.0, *)
  @Test("render every Customer Center state for design review")
  func renderAll() async throws {
    let directory = try #require(Self.outputDirectory)
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    // 1. Nothing purchased — the empty state.
    capture("01-no-purchases", directory: directory, viewModel: await makeViewModel())

    // 2. One active auto-renewing subscription. The single-purchase layout, which shows the
    //    purchase card and its actions together rather than a drill-down list.
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

    // 12. More one-off purchases than the management screen shows inline, with the purchase
    //     history screen available to show the rest.
    let manyPurchases = await makeViewModel(
      subscriptions: [subscription()],
      nonSubscriptions: [
        nonSubscription(),
        nonSubscription(productId: "extra_theme", transactionId: "n2", purchaseDate: -60),
        nonSubscription(productId: "coins_500", transactionId: "n3", purchaseDate: -20, isConsumable: true),
        nonSubscription(productId: "coins_500", transactionId: "n4", purchaseDate: -8, isConsumable: true)
      ]
    )
    capture("12-many-purchases-collapsed", directory: directory, viewModel: manyPurchases)

    // 13. The purchase history screen those rows lead to.
    captureDetail("13-purchase-history", directory: directory, viewModel: manyPurchases) {
      PurchaseHistoryView(viewModel: manyPurchases)
    }

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

    // 19. History and account details switched off — the most stripped-back screen.
    let minimal = defaultConfiguration()
    minimal.showsPurchaseHistory = false
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

    let written = (try? FileManager.default.contentsOfDirectory(atPath: directory.path))?
      .filter { $0.hasSuffix(".png") }
      .count ?? 0
    Issue.record(Comment(rawValue: "WROTE \(written) PNGs to \(directory.path)"))
  }
}
