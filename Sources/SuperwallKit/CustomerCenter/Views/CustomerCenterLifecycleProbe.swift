//
//  CustomerCenterLifecycleProbe.swift
//
//
//  Created by Jordan Morgan on 23/09/2026.
//

import SwiftUI
import UIKit

/// Tells a Customer Center screen whether it was covered or removed when it disappeared.
///
/// SwiftUI's `onDisappear` fires for both. A screen the host has covered — by switching tabs,
/// pushing a screen of its own or presenting over it — is still in the stack and will come back,
/// so it keeps its claim on the sheets and mustn't deliver a dismissal. A screen that was popped
/// or dismissed is gone. UIKit knows which happened and SwiftUI doesn't say, so a hidden child
/// controller in the screen listens for it.
@available(iOS 15.0, *)
struct CustomerCenterLifecycleProbe: UIViewControllerRepresentable {
  /// The screen disappeared but is still in the stack.
  var onCovered: () -> Void
  /// The screen disappeared because it left the stack.
  var onRemoved: () -> Void
  /// SwiftUI took the screen down. This also happens to a screen that was covered first, which
  /// doesn't disappear a second time on its way out. A cancelled swipe back takes nothing down.
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
    controller.onDismantled?()
  }
}

@available(iOS 15.0, *)
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
