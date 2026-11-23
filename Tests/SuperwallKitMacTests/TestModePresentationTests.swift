// swiftlint:disable all
#if os(macOS)
import AppKit
import SwiftUI
import Testing
@testable import SuperwallKit

@Suite(.serialized)
@MainActor
struct TestModePresentationTests {
  @Test
  func closingHostCancelsSimulationExactlyOnce() async throws {
    _ = NSApplication.shared
    let root = NSViewController.blank()
    let window = NSWindow(contentViewController: root)
    window.isReleasedWhenClosed = false
    window.setContentSize(NSSize(width: 600, height: 500))
    window.orderFront(nil)
    var cancellations = 0
    TestModeSheetPresenter.present(
      size: CGSize(width: 300, height: 200), on: root,
      onCancel: { cancellations += 1 }
    ) { _ in Text("Simulated purchase").frame(width: 300, height: 200) }
    try await Task.sleep(nanoseconds: 200_000_000)
    window.close()
    try await Task.sleep(nanoseconds: 500_000_000)
    #expect(cancellations == 1)
  }

  @Test
  func explicitCompletionIsSingleUseAndDoesNotCancel() async throws {
    _ = NSApplication.shared
    var finish: (() -> Bool)?
    var cancellations = 0
    TestModeSheetPresenter.present(
      size: CGSize(width: 300, height: 200), on: nil,
      onCancel: { cancellations += 1 }
    ) { close in
      finish = close
      return Text("Test Mode").frame(width: 300, height: 200)
    }
    #expect(finish?() == true)
    #expect(finish?() == false)
    try await Task.sleep(nanoseconds: 200_000_000)
    #expect(cancellations == 0)
  }
}
#endif
