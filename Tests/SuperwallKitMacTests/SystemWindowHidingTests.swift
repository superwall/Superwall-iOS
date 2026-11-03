// swiftlint:disable all
#if os(macOS)
import AppKit
import SwiftUI
import Testing
@testable import SuperwallKit

private final class FinishRecorder: PaywallViewControllerDelegate {
  var finishCount = 0

  func paywall(
    _ paywall: PaywallViewController,
    didFinishWith result: PaywallResult,
    shouldDismiss: Bool
  ) {
    finishCount += 1
  }
}

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
  func orderingTheWindowOutDoesNotEndCheckout() async throws {
    let parent = makeParent()
    defer { parent.close() }
    var dismissals = 0
    let checkout = CheckoutWebViewController(url: URL(string: "about:blank")!)
    checkout.onDismiss = { dismissals += 1 }
    parent.contentViewController?.presentAsSheet(checkout)
    try await settle()

    parent.orderOut(nil)
    try await settle()
    #expect(dismissals == 0)

    // Closing checkout from code while the window is hidden still reports it.
    checkout.dismissFromPaywall()
    try await settle()
    #expect(dismissals == 1)

    parent.orderFront(nil)
    try await settle()
    #expect(dismissals == 1)
  }

  @Test
  func closingCheckoutStillEndsIt() async throws {
    let parent = makeParent()
    defer { parent.close() }
    var dismissals = 0
    let checkout = CheckoutWebViewController(url: URL(string: "about:blank")!)
    checkout.onDismiss = { dismissals += 1 }
    parent.contentViewController?.presentAsSheet(checkout)
    try await settle()

    parent.contentViewController?.dismiss(checkout)
    try await settle()
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
  func paywallIsClosingOnlyWhileLeavingForGood() async throws {
    let parent = makeParent()
    defer { parent.close() }
    let paywall = makePaywallViewController()
    parent.contentViewController?.presentAsSheet(paywall)
    try await settle()
    #expect(!paywall.isClosing)

    parent.miniaturize(nil)
    try await settle(1.5)
    #expect(!paywall.isClosing)
    parent.deminiaturize(nil)
    try await settle(1.5)
    #expect(!paywall.isClosing)

    // A sheet closes in one step, before `dismiss` returns.
    paywall.presentingViewController?.dismiss(paywall)
    #expect(!paywall.isClosing)
    #expect(paywall.presentingViewController == nil)

    // An overlay is closing while it animates out.
    let host = try #require(parent.contentViewController)
    host.present(paywall, animator: PaywallOverlayAnimator(transition: .fade))
    try await settle()
    #expect(!paywall.isClosing)
    host.dismiss(paywall)
    #expect(paywall.isClosing)
    try await settle()
    #expect(!paywall.isClosing)
    #expect(paywall.view.superview == nil)
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

  @Test
  func paywallShownInAnotherWindowAfterBeingTakenDownWhileHidden() async throws {
    let parent = makeParent()
    defer { parent.close() }
    let other = makeParent()
    defer { other.close() }
    let paywall = makePaywallViewController()
    let recorder = FinishRecorder()
    paywall.delegate = PaywallViewControllerDelegateAdapter(
      swiftDelegate: recorder,
      objcDelegate: nil
    )
    parent.contentViewController?.presentAsSheet(paywall)
    try await settle()

    parent.miniaturize(nil)
    try await settle(1.5)
    #expect(paywall.isHiddenWithWindow)

    // Taken down while hidden, then shown again elsewhere before the first
    // window comes back.
    paywall.presentingViewController?.dismiss(paywall)
    other.contentViewController?.presentAsSheet(paywall)
    try await settle()
    #expect(!paywall.isHiddenWithWindow)
    #expect(paywall.view.window?.sheetParent === other)
    other.contentViewController?.dismiss(paywall)
    parent.deminiaturize(nil)
    try await settle(1.5)

    // Once for each close. If the first close finished after the paywall
    // appeared again, it would have reset that presentation and the second
    // close would go unreported.
    #expect(recorder.finishCount == 2)
  }

  @Test
  func paywallShownAgainRightAfterItsWindowReturnsWithoutIt() async throws {
    let parent = makeParent()
    defer { parent.close() }
    let paywall = makePaywallViewController()
    let recorder = FinishRecorder()
    paywall.delegate = PaywallViewControllerDelegateAdapter(
      swiftDelegate: recorder,
      objcDelegate: nil
    )
    parent.contentViewController?.presentAsSheet(paywall)
    try await settle()
    // The dismissal reads the page's state first. Make that take a while, so
    // the old dismissal is still running when the paywall is shown again. The
    // SDK connects the message handler when it makes a paywall; this test
    // makes its own.
    paywall.webView.messageHandler.delegate = paywall
    paywall.webView.loadHTMLString(
      """
      <script>
      window.app = { getAllState() { const end = Date.now() + 1500; while (Date.now() < end) {} return {}; } };
      </script>
      """,
      baseURL: nil
    )
    try await settle()

    parent.miniaturize(nil)
    try await settle(1.5)
    #expect(paywall.isHiddenWithWindow)

    // Taken down while hidden. The window coming back starts that dismissal,
    // and the app shows the same paywall again while it's still running.
    paywall.presentingViewController?.dismiss(paywall)
    parent.deminiaturize(nil)
    for _ in 0..<300 where paywall.isHiddenWithWindow {
      try await Task.sleep(nanoseconds: 5_000_000)
    }
    #expect(!paywall.isHiddenWithWindow)
    parent.contentViewController?.presentAsSheet(paywall)
    // Let the old dismissal finish and the new presentation start.
    try await settle(2.5)
    parent.contentViewController?.dismiss(paywall)
    try await settle(2.5)

    // Once for each close. If the first close finished after the paywall
    // appeared again, it would have reset that presentation and the second
    // close would go unreported.
    #expect(recorder.finishCount == 2)
  }

  @Test
  func paywallTakenDownAgainBeforeItsDelayedAppearanceIsNotLeftPresented() async throws {
    let parent = makeParent()
    defer { parent.close() }
    let paywall = makePaywallViewController()
    let recorder = FinishRecorder()
    paywall.delegate = PaywallViewControllerDelegateAdapter(
      swiftDelegate: recorder,
      objcDelegate: nil
    )
    parent.contentViewController?.presentAsSheet(paywall)
    try await settle()
    // Hold the old dismissal open, as in the test above.
    paywall.webView.messageHandler.delegate = paywall
    paywall.webView.loadHTMLString(
      """
      <script>
      window.app = { getAllState() { const end = Date.now() + 1500; while (Date.now() < end) {} return {}; } };
      </script>
      """,
      baseURL: nil
    )
    try await settle()

    parent.miniaturize(nil)
    try await settle(1.5)
    paywall.presentingViewController?.dismiss(paywall)
    parent.deminiaturize(nil)
    for _ in 0..<300 where paywall.isHiddenWithWindow {
      try await Task.sleep(nanoseconds: 5_000_000)
    }

    // Shown again, then taken down again while its appearance still waits for
    // the old dismissal.
    parent.contentViewController?.presentAsSheet(paywall)
    try await settle()
    parent.contentViewController?.dismiss(paywall)
    try await settle(2.5)

    #expect(!paywall.isPresented, "a paywall taken down before it appeared was left marked as presented")
    #expect(recorder.finishCount == 1)
  }
}
#endif
