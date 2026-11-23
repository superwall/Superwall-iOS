// swiftlint:disable all
#if os(macOS)
import AppKit
import SwiftUI
import Testing
@testable import SuperwallKit

@Suite(.serialized)
@MainActor
struct PaywallWindowTests {
  private func settle() async throws {
    try await Task.sleep(nanoseconds: 100_000_000)
  }

  @Test
  func cachedSheetSizeDoesNotResizeOverlayOrSwiftUIHost() async throws {
    _ = NSApplication.shared
    let parent = NSWindow(
      contentRect: NSRect(x: 100, y: 100, width: 760, height: 620),
      styleMask: [.titled, .resizable], backing: .buffered, defer: false
    )
    parent.isReleasedWhenClosed = false
    parent.contentViewController = NSHostingController(rootView: Text("Host").frame(minWidth: 300, minHeight: 200))
    parent.orderFront(nil)
    defer { parent.close() }
    try await settle()
    let originalFrame = parent.frame
    let paywall = NSViewController.blank()

    // A cached controller comes out of a drawer with this preferred size.
    // Then a popup can give it a zero fitting size. Neither may size the host.
    for preferred in [CGSize(width: 480, height: 432), .zero] {
      paywall.preferredContentSize = preferred
      let overlay = PaywallOverlayWindow(over: parent)
      overlay.host.present(paywall, animator: PaywallOverlayAnimator(transition: .none))
      try await settle()
      let expected = parent.convertToScreen(parent.contentLayoutRect)
      #expect(overlay.frame == expected)
      #expect(paywall.view.bounds.size == expected.size)
      #expect(parent.frame == originalFrame)
      overlay.host.dismiss(paywall)
      try await settle()
      #expect(paywall.presentingViewController == nil)
      overlay.close()
      #expect(parent.childWindows?.isEmpty != false)
    }
  }

  @Test
  func overlayFollowsParentResize() async throws {
    _ = NSApplication.shared
    let parent = NSWindow(
      contentRect: NSRect(x: 100, y: 100, width: 600, height: 500),
      styleMask: [.titled, .resizable], backing: .buffered, defer: false
    )
    parent.isReleasedWhenClosed = false
    parent.orderFront(nil)
    let overlay = PaywallOverlayWindow(over: parent)
    defer { overlay.close(); parent.close() }
    let controller = NSViewController.blank()
    overlay.host.present(controller, animator: PaywallOverlayAnimator(transition: .none))
    parent.setContentSize(NSSize(width: 820, height: 640))
    try await settle()
    #expect(overlay.frame == parent.convertToScreen(parent.contentLayoutRect))
    #expect(controller.view.bounds.size == overlay.contentLayoutRect.size)
    overlay.host.dismiss(controller)
  }
}
#endif
