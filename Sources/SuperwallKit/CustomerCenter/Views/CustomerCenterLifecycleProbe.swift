//
//  CustomerCenterLifecycleProbe.swift
//
//
//  Created by Jordan Morgan on 23/09/2026.
//

import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

#if os(macOS)
/// Tells a Customer Center screen whether it was covered or removed when it disappeared.
///
/// The AppKit counterpart of the UIKit probe below. AppKit marks nothing on a controller being
/// dismissed or popped, and a navigation stack takes the screens under the top one out of the
/// window, so leaving the window can't be read as leaving the stack. Only a window that closed
/// counts as removal here. A popped screen is reported when SwiftUI takes it down instead.
struct CustomerCenterLifecycleProbe: NSViewControllerRepresentable {
  /// The screen disappeared but is still in the stack.
  var onCovered: () -> Void
  /// The screen disappeared because its window closed.
  var onRemoved: () -> Void
  /// SwiftUI took the screen down, reported once its update has finished.
  var onDismantled: () -> Void

  func makeNSViewController(context: Context) -> CustomerCenterLifecycleProbeController {
    let controller = CustomerCenterLifecycleProbeController()
    updateNSViewController(controller, context: context)
    return controller
  }

  func updateNSViewController(_ controller: CustomerCenterLifecycleProbeController, context: Context) {
    controller.onCovered = onCovered
    controller.onRemoved = onRemoved
    controller.onDismantled = onDismantled
  }

  static func dismantleNSViewController(
    _ controller: CustomerCenterLifecycleProbeController,
    coordinator: ()
  ) {
    // Changing observed state in the middle of SwiftUI's update is undefined behaviour.
    let onDismantled = controller.onDismantled
    DispatchQueue.main.async { onDismantled?() }
  }
}

final class CustomerCenterLifecycleProbeController: NSViewController {
  var onCovered: (() -> Void)?
  var onRemoved: (() -> Void)?
  var onDismantled: (() -> Void)?
  /// Where the screen was last shown. A screen taken out of the window has already lost it by the
  /// time it's told it disappeared.
  private weak var window: NSWindow?

  override func loadView() {
    let view = NSView()
    view.isHidden = true
    self.view = view
  }

  override func viewDidAppear() {
    super.viewDidAppear()
    window = view.window ?? window
  }

  override func viewDidDisappear() {
    super.viewDidDisappear()
    // A window that's closing is still on its way off screen here, so look on the next turn of
    // the run loop.
    DispatchQueue.main.async { [weak self] in
      guard let self = self else {
        return
      }
      if self.hasLeftHierarchy {
        self.onRemoved?()
      } else {
        self.onCovered?()
      }
    }
  }

  /// Whether this disappearance is the screen's window closing, rather than the screen being
  /// covered or its window hidden.
  var hasLeftHierarchy: Bool {
    return window?.isClosedRatherThanHidden ?? false
  }
}
#else
/// Tells a Customer Center screen whether it was covered or removed when it disappeared.
///
/// SwiftUI's `onDisappear` fires for both. A screen the host has covered — by switching tabs,
/// pushing a screen of its own or presenting over it — is still in the stack and will come back,
/// so it keeps its claim on the sheets and mustn't deliver a dismissal. A screen that was popped
/// or dismissed is gone. UIKit knows which happened and SwiftUI doesn't say, so a hidden child
/// controller in the screen listens for it.
struct CustomerCenterLifecycleProbe: UIViewControllerRepresentable {
  /// The screen disappeared but is still in the stack.
  var onCovered: () -> Void
  /// The screen disappeared because it left the stack.
  var onRemoved: () -> Void
  /// SwiftUI took the screen down, reported once its update has finished. This also happens to a
  /// screen that was covered first, which doesn't disappear a second time on its way out. A
  /// cancelled swipe back takes nothing down.
  var onDismantled: () -> Void

  func makeUIViewController(context: Context) -> CustomerCenterLifecycleProbeController {
    let controller = CustomerCenterLifecycleProbeController()
    updateUIViewController(controller, context: context)
    return controller
  }

  func updateUIViewController(_ controller: CustomerCenterLifecycleProbeController, context: Context) {
    controller.onCovered = onCovered
    controller.onRemoved = onRemoved
    controller.onDismantled = onDismantled
  }

  static func dismantleUIViewController(
    _ controller: CustomerCenterLifecycleProbeController,
    coordinator: ()
  ) {
    // SwiftUI takes views down in the middle of an update, and changing state it observes there is
    // undefined behaviour. What this reports can clear a sheet, so it waits for the update to end.
    let onDismantled = controller.onDismantled
    DispatchQueue.main.async { onDismantled?() }
  }
}

final class CustomerCenterLifecycleProbeController: UIViewController {
  var onCovered: (() -> Void)?
  var onRemoved: (() -> Void)?
  var onDismantled: (() -> Void)?
  /// Where the screen was last shown, recorded while it's still there: a screen covered by a
  /// full-screen presentation has already left the window by the time it's told it disappeared.
  private weak var window: UIWindow?

  override func loadView() {
    let view = UIView()
    view.isHidden = true
    view.isUserInteractionEnabled = false
    self.view = view
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    window = view.window ?? window
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    window = view.window ?? window
  }

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    if hasLeftHierarchy {
      onRemoved?()
    } else {
      onCovered?()
    }
  }

  /// Whether this disappearance is the screen leaving rather than being covered.
  ///
  /// UIKit marks a controller it pops or dismisses, or the container it's in, which is why the
  /// chain is walked. SwiftUI's `NavigationStack` marks nothing: it has already detached a popped
  /// screen from its navigation controller by the time the screen is told it disappeared. A covered
  /// screen is still attached all the way up, to a presented controller or to the window's root,
  /// so a screen attached to neither has left as well.
  var hasLeftHierarchy: Bool {
    if isLeavingHierarchyOrAContainerIs {
      return true
    }
    var top: UIViewController = self
    while let parent = top.parent {
      top = parent
    }
    return top.presentingViewController == nil && top !== window?.rootViewController
  }
}
#endif
