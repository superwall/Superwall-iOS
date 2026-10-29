// swiftlint:disable all
#if os(macOS)
import AppKit
import Testing
@testable import SuperwallKit

@Suite(.serialized)
@MainActor
struct CustomerCenterDismissalTests {
  private final class Recorder {
    var events: [String] = []
  }

  private final class Delegate: CustomerCenterDelegate {
    let recorder: Recorder
    init(_ recorder: Recorder) { self.recorder = recorder }
    func customerCenterDidDismiss() { recorder.events.append("delegate") }
  }

  private func waitUntil(_ condition: () -> Bool) async throws {
    let deadline = Date().addingTimeInterval(3)
    while !condition(), Date() < deadline {
      try await Task.sleep(nanoseconds: 10_000_000)
    }
    #expect(condition())
  }

  @Test(arguments: [true, false])
  func dismissalDeliversCallbacksBeforeReleasingOwnership(programmatic: Bool) async throws {
    _ = NSApplication.shared
    let container = DependencyContainer()
    let manager = CustomerCenterManager(container: container)
    let root = NSViewController.blank()
    let window = NSWindow(contentViewController: root)
    window.isReleasedWhenClosed = false
    window.setContentSize(NSSize(width: 760, height: 620))
    window.orderFront(nil)
    defer { window.close() }
    let recorder = Recorder()
    var delegate: Delegate? = Delegate(recorder)
    weak var weakDelegate = delegate
    manager.present(configuration: nil, from: root, delegate: delegate) {
      recorder.events.append("onDismiss")
    }
    delegate = nil
    weak var controller = manager.presentedControllerForTesting
    try await waitUntil { controller?.wasPresentedModally == true }
    #expect(weakDelegate != nil)
    if programmatic {
      manager.dismiss { recorder.events.append("completion") }
    } else if let presented = root.presentedViewControllers?.last {
      root.dismiss(presented)
    }
    let expected = programmatic ? ["delegate", "onDismiss", "completion"] : ["delegate", "onDismiss"]
    try await waitUntil { recorder.events == expected }
    #expect(!manager.isPresented)
    try await waitUntil { weakDelegate == nil && controller == nil }
    // A second dismissal must not replay either callback.
    manager.dismiss(completion: nil)
    #expect(recorder.events == expected)
  }
}
#endif
