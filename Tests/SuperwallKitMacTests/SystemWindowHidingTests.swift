// swiftlint:disable all
#if os(macOS)
import AppKit
import SwiftUI
import Testing
@testable import SuperwallKit

@Suite(.serialized)
@MainActor
struct SystemWindowHidingTests {
  private func settle(_ seconds: Double = 0.5) async throws {
    try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
  }

  private func makeParent() -> NSWindow {
    _ = NSApplication.shared
    SystemWindowHiding.start()
    let parent = NSWindow(
      contentRect: NSRect(x: 100, y: 100, width: 600, height: 500),
      styleMask: [.titled, .miniaturizable, .closable],
      backing: .buffered,
      defer: false
    )
    parent.isReleasedWhenClosed = false
    parent.contentViewController = NSViewController.blank()
    parent.makeKeyAndOrderFront(nil)
    return parent
  }

  @Test
  func sheetAndOverlayOfMinimisedWindowAreHiddenNotClosed() async throws {
    let parent = makeParent()
    defer { parent.close() }
    let sheet = NSViewController.blank()
    parent.contentViewController?.presentAsSheet(sheet)
    let overlay = PaywallOverlayWindow(over: parent)
    defer { overlay.close() }
    try await settle()
    #expect(sheet.view.window?.isHiddenBySystem == false)
    #expect(overlay.isHiddenBySystem == false)

    parent.miniaturize(nil)
    try await settle(1.5)
    #expect(sheet.view.window?.isHiddenBySystem == true)
    #expect(sheet.view.window?.isClosedRatherThanHidden == false)
    #expect(overlay.isHiddenBySystem == true)

    parent.deminiaturize(nil)
    try await settle(1.5)
    parent.contentViewController?.dismiss(sheet)
  }

  @Test
  func minimisingDoesNotEndCheckout() async throws {
    let parent = makeParent()
    defer { parent.close() }
    var dismissals = 0
    let checkout = CheckoutWebViewController(url: URL(string: "about:blank")!)
    checkout.onDismiss = { dismissals += 1 }
    parent.contentViewController?.presentAsSheet(checkout)
    try await settle()

    parent.miniaturize(nil)
    try await settle(1.5)
    #expect(dismissals == 0)

    // Closing checkout from code while the window is minimised still reports it.
    checkout.dismissFromPaywall()
    try await settle()
    #expect(dismissals == 1)
    #expect(checkout.presentingViewController == nil)

    parent.deminiaturize(nil)
    try await settle(1.5)
    #expect(dismissals == 1)
  }

  @Test
  func minimisingDoesNotCancelTestModeSheet() async throws {
    let parent = makeParent()
    defer { parent.close() }
    var cancellations = 0
    var finish: (() -> Bool)?
    TestModeSheetPresenter.present(
      size: CGSize(width: 300, height: 200),
      on: parent.contentViewController,
      onCancel: { cancellations += 1 }
    ) { close in
      finish = close
      return Text("Simulated purchase").frame(width: 300, height: 200)
    }
    try await settle()

    parent.miniaturize(nil)
    try await settle(1.5)
    #expect(cancellations == 0)

    parent.deminiaturize(nil)
    try await settle(1.5)
    #expect(cancellations == 0)
    #expect(finish?() == true)
  }

  private func makePaywallViewController() -> PaywallViewController {
    let dependencyContainer = DependencyContainer()
    return PaywallViewController(
      paywall: .stub(),
      deviceHelper: dependencyContainer.deviceHelper,
      factory: dependencyContainer,
      storage: dependencyContainer.storage,
      network: dependencyContainer.network,
      webView: SWWebView(
        isiOSAppOnMac: false,
        messageHandler: .init(
          receiptManager: dependencyContainer.receiptManager,
          factory: dependencyContainer,
          permissionHandler: dependencyContainer.permissionHandler,
          customCallbackRegistry: dependencyContainer.customCallbackRegistry
        ),
        isOnDeviceCacheEnabled: false,
        factory: dependencyContainer
      ),
      webEntitlementRedeemer: dependencyContainer.webEntitlementRedeemer,
      cache: dependencyContainer.makeCache(),
      paywallArchiveManager: dependencyContainer.paywallArchiveManager,
      customCallbackRegistry: dependencyContainer.customCallbackRegistry
    )
  }

  @Test
  func paywallRestoredWithItsWindowStaysHiddenUntilItAppears() async throws {
    let parent = makeParent()
    defer { parent.close() }
    let paywall = makePaywallViewController()
    parent.contentViewController?.presentAsSheet(paywall)
    try await settle()

    parent.miniaturize(nil)
    try await settle(1.5)
    #expect(paywall.isHiddenWithWindow)

    parent.deminiaturize(nil)
    try await settle(1.5)
    #expect(!paywall.isHiddenWithWindow)
    #expect(paywall.presentingViewController != nil)
    paywall.presentingViewController?.dismiss(paywall)
  }

  @Test
  func paywallTakenDownWhileHiddenFinishesItsDismissal() async throws {
    let parent = makeParent()
    defer { parent.close() }
    let paywall = makePaywallViewController()
    parent.contentViewController?.presentAsSheet(paywall)
    try await settle()

    parent.miniaturize(nil)
    try await settle(1.5)
    #expect(paywall.isHiddenWithWindow)

    // As an app does from a `getPaywall` delegate, with the window minimised.
    paywall.presentingViewController?.dismiss(paywall)
    parent.deminiaturize(nil)
    try await settle(1.5)
    #expect(!paywall.isHiddenWithWindow)
  }
}
#endif
