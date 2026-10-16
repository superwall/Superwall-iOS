#if os(macOS)
import AppKit
import SwiftUI

// MARK: - Presenting

/// Shows a test mode sheet over the app.
@MainActor
enum TestModeSheetPresenter {
  /// Shows `content` as a sheet on `viewController`'s window, or in a window of its own when
  /// there's no window to attach it to. `content` receives the action that closes it.
  static func present<Content: View>(
    size: CGSize,
    on viewController: NSViewController?,
    onCancel: @escaping () -> Void,
    content: (_ close: @escaping () -> Bool) -> Content
  ) {
    var didFinish = false
    var dismiss: () -> Void = {}
    let finish = { () -> Bool in
      guard !didFinish else { return false }
      didFinish = true
      let action = dismiss
      dismiss = {} // Break the standalone window -> content -> dismissal closure cycle.
      action()
      return true
    }
    SystemWindowHiding.start()
    let hostingController = TestModeHostingController(rootView: content(finish))
    hostingController.preferredContentSize = size
    hostingController.onCancel = {
      guard finish() else { return }
      onCancel()
    }

    if let viewController = viewController,
      viewController.view.window != nil {
      dismiss = { [weak hostingController] in
        guard let hostingController = hostingController else { return }
        hostingController.presentingViewController?.dismiss(hostingController)
      }
      viewController.presentAsSheet(hostingController)
      return
    }

    let window = NSWindow(contentViewController: hostingController)
    window.styleMask = [.titled]
    window.title = "Test Mode"
    window.isReleasedWhenClosed = false
    window.setContentSize(size)
    window.center()
    dismiss = { window.close() }
    window.makeKeyAndOrderFront(nil)
    PlatformApplication.sharedApplication?.activate(ignoringOtherApps: true)
  }
}

/// Completes pending simulations when the host window is closed externally.
private final class TestModeHostingController<Content: View>: NSHostingController<Content> {
  var onCancel: (() -> Void)?

  override func viewDidDisappear() {
    super.viewDidDisappear()
    DispatchQueue.main.async { [self] in
      // A minimised window or a hidden app brings the sheet back later.
      if view.window?.isHiddenBySystem == true {
        return
      }
      guard presentingViewController == nil || view.window?.isVisible != true else { return }
      let callback = onCancel
      onCancel = nil
      callback?()
    }
  }
}

#endif
