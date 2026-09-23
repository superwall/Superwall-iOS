//
//  CustomerCenterDrillDownSheetTests.swift
//
//
//  Created by Jordan Morgan on 23/09/2026.
//

import Testing
import Foundation
import SwiftUI
import UIKit
@testable import SuperwallKit

/// Sheets requested from a subscription's own screen, when SwiftUI's `NavigationLink` pushed it.
///
/// A sheet can only present from a screen that's in the window, and UIKit takes the screens under
/// a pushed one out of it — so a pushed screen has to carry its own sheet modifiers and own them
/// while it's on top. These host the real `CustomerCenterView` and open the detail screen through
/// the real drill-down row, because the bug they guard against lived in which screen carried the
/// modifiers, which no test of the view model alone can see.
///
/// This test host has no window scene, and without one UIKit leaves a covered screen in the window.
/// The root could therefore present here even though it can't on a device, which is why these
/// assert which screen owns the sheets as well as that the sheet appeared.
@Suite("Customer Center drill-down sheets", .serialized)
@MainActor
struct CustomerCenterDrillDownSheetTests {
  private static let now = Date()

  @available(iOS 15.0, *)
  private func makeLoadedViewModel() async -> CustomerCenterViewModel {
    let subscription = SubscriptionTransaction(
      transactionId: "t1",
      productId: "monthly_pro",
      purchaseDate: Self.now.addingTimeInterval(-30 * 86_400),
      willRenew: true,
      isRevoked: false,
      isInGracePeriod: false,
      isInBillingRetryPeriod: false,
      isActive: true,
      expirationDate: Self.now.addingTimeInterval(12 * 86_400),
      offerType: nil,
      subscriptionGroupId: "group_pro",
      store: .appStore
    )
    let (deps, _, _) = CustomerCenterDependencies.mock(
      info: CustomerInfo(subscriptions: [subscription], nonSubscriptions: [], entitlements: [])
    )
    let viewModel = CustomerCenterViewModel(configuration: .default, dependencies: deps, strings: .english)
    await viewModel.load()
    return viewModel
  }

  private func makeWindow(rootViewController: UIViewController) -> UIWindow {
    let window: UIWindow
    if let scene = UIApplication.sharedApplication?.connectedScenes.first as? UIWindowScene {
      window = UIWindow(windowScene: scene)
      window.frame = scene.screen.bounds
    } else {
      window = UIWindow(frame: UIScreen.main.bounds)
    }
    window.rootViewController = rootViewController
    return window
  }

  private func spinRunLoop(timeout: TimeInterval, until condition: () -> Bool) {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition() && Date() < deadline {
      RunLoop.current.run(until: Date().addingTimeInterval(0.05))
    }
  }

  private func firstSubview<T: UIView>(of type: T.Type, in view: UIView) -> T? {
    if let match = view as? T { return match }
    for subview in view.subviews {
      if let match = firstSubview(of: type, in: subview) { return match }
    }
    return nil
  }

  private func firstChild<T: UIViewController>(of type: T.Type, in controller: UIViewController) -> T? {
    if let match = controller as? T { return match }
    for child in controller.children {
      if let match = firstChild(of: type, in: child) { return match }
    }
    return nil
  }

  /// Opens the first subscription's screen the way a tap on its row does: through the list's own
  /// selection, which is what drives the row's `NavigationLink`.
  private func openFirstSubscription(in host: UIViewController) throws -> UINavigationController {
    var list: UICollectionView?
    spinRunLoop(timeout: 2) {
      list = firstSubview(of: UICollectionView.self, in: host.view)
      return (list?.numberOfSections ?? 0) > 0
    }
    let collectionView = try #require(list, "the management screen's list never loaded")
    let row = IndexPath(item: 0, section: 0)
    collectionView.selectItem(at: row, animated: false, scrollPosition: [])
    collectionView.delegate?.collectionView?(collectionView, didSelectItemAt: row)

    var navigation: UINavigationController?
    spinRunLoop(timeout: 3) {
      navigation = firstChild(of: UINavigationController.self, in: host)
      guard let navigation, navigation.viewControllers.count == 2 else { return false }
      return navigation.topViewController?.viewIfLoaded?.window != nil
        && navigation.transitionCoordinator == nil
    }
    let pushed = try #require(navigation, "no navigation controller hosts the Customer Center")
    try #require(pushed.viewControllers.count == 2, "the subscription's screen never opened")
    return pushed
  }

  /// Asks for the cancellation survey from the subscription's screen and reports whether anything
  /// was presented over it.
  @available(iOS 15.0, *)
  private func requestSurvey(from viewModel: CustomerCenterViewModel, window: UIWindow) async throws -> Bool {
    let purchase = try #require(viewModel.purchases.first)
    let cancel = try #require(
      viewModel.paths(for: purchase, isScreenLevel: false).first { $0.path.id == "manage_subscription" }
    )
    await viewModel.select(cancel, purchase: purchase)
    #expect(viewModel.sheet == .survey(pathId: cancel.path.id))

    spinRunLoop(timeout: 2) { window.rootViewController?.presentedViewController != nil }
    return window.rootViewController?.presentedViewController != nil
  }

  @available(iOS 15.0, *)
  @Test("the survey presents over a subscription's screen when the Customer Center brings its own navigation")
  func surveyPresentsFromDetailInOwnNavigation() async throws {
    let viewModel = await makeLoadedViewModel()
    let host = UIHostingController(
      rootView: CustomerCenterView(viewModel: viewModel, navigationOptions: .default)
    )
    let window = makeWindow(rootViewController: host)
    window.makeKeyAndVisible()
    defer { window.isHidden = true }

    _ = try openFirstSubscription(in: host)
    #expect(viewModel.pushDepth == 1, "the subscription's screen must own the sheets while it's on top")
    let presented = try await requestSurvey(from: viewModel, window: window)

    #expect(presented, "the survey waited for the covered root screen instead of presenting over the detail")
    host.dismiss(animated: false, completion: nil)
  }

  @available(iOS 16.0, *)
  @Test("the survey presents over a subscription's screen pushed onto the host's navigation")
  func surveyPresentsFromDetailInHostNavigation() async throws {
    let viewModel = await makeLoadedViewModel()
    let host = UIHostingController(
      rootView: NavigationStack {
        CustomerCenterView(viewModel: viewModel, navigationOptions: .init(style: .embedded))
      }
    )
    let window = makeWindow(rootViewController: host)
    window.makeKeyAndVisible()
    defer { window.isHidden = true }

    _ = try openFirstSubscription(in: host)
    #expect(viewModel.pushDepth == 1, "the subscription's screen must own the sheets while it's on top")
    let presented = try await requestSurvey(from: viewModel, window: window)

    #expect(presented, "the survey waited for the covered root screen instead of presenting over the detail")
    host.dismiss(animated: false, completion: nil)
  }

  @available(iOS 15.0, *)
  @Test("going back from a subscription's screen hands sheets back to the root")
  func poppingTheDetailRestoresRootOwnership() async throws {
    let viewModel = await makeLoadedViewModel()
    let host = UIHostingController(
      rootView: CustomerCenterView(viewModel: viewModel, navigationOptions: .default)
    )
    let window = makeWindow(rootViewController: host)
    window.makeKeyAndVisible()
    defer { window.isHidden = true }

    let navigation = try openFirstSubscription(in: host)
    #expect(viewModel.pushDepth == 1)

    navigation.popViewController(animated: false)
    spinRunLoop(timeout: 2) { viewModel.pushDepth == 0 }
    #expect(viewModel.pushDepth == 0, "the root must be able to present again once the detail is gone")
  }
}
