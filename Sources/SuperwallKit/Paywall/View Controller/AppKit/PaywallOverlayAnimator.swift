//
//  PaywallOverlayAnimator.swift
//  SuperwallKit
//
//  Created by Brian Anglin on 13/10/2026.
//

#if os(macOS)
import AppKit

/// The size a paywall is shown at in a sheet or a window of its own.
///
/// Paywalls are designed for a phone held upright, so this is a tall, narrow
/// size that leaves the layout as designed, kept within the screen.
enum PaywallSheetSize {
  static let preferred = CGSize(width: 480, height: 720)

  /// Room left between the sheet and the edges of the screen.
  private static let screenMargin = CGSize(width: 40, height: 80)

  /// The preferred size, shrunk to fit the screen `window` is on.
  static func fitting(_ window: NSWindow?) -> CGSize {
    guard let visibleFrame = (window?.screen ?? NSScreen.main)?.visibleFrame else {
      return preferred
    }
    return CGSize(
      width: min(preferred.width, visibleFrame.width - screenMargin.width),
      height: min(preferred.height, visibleFrame.height - screenMargin.height)
    )
  }
}

/// A window the SDK shows paywalls in, presenting them from ``host``, a view
/// controller whose view fills the window.
///
/// The host's required size comes from the window, not the presented controller's
/// preferredContentSize. Cached controllers retain sheet sizes, and AppKit would
/// otherwise resize an overlay window to that stale size (or zero).
class PaywallHostWindow: NSWindow {
  /// What paywalls are presented on.
  let host = NSViewController.blank()
  private var sizeConstraints: [NSLayoutConstraint] = []

  init(contentRect: NSRect, styleMask: NSWindow.StyleMask) {
    super.init(
      contentRect: contentRect,
      styleMask: styleMask,
      backing: .buffered,
      defer: false
    )
    isReleasedWhenClosed = false
    contentView = host.view
    sizeConstraints = [
      host.view.widthAnchor.constraint(equalToConstant: contentRect.width),
      host.view.heightAnchor.constraint(equalToConstant: contentRect.height)
    ]
    NSLayoutConstraint.activate(sizeConstraints)
  }

  func fit(to frame: NSRect) {
    sizeConstraints[0].constant = frame.width
    sizeConstraints[1].constant = frame.height
    setFrame(frame, display: true)
  }
}

/// A borderless window laid over the content of one of the app's windows, which
/// full screen, push and popup paywalls are shown in.
///
/// It's the macOS counterpart of the window iOS covers the app with, and for the
/// same reason: the paywall never joins a view hierarchy the app owns. A SwiftUI
/// window's content is an `NSHostingView` that lays out its own subviews, and one
/// added from outside sends it into an endless constraint pass.
///
/// As a child of the app's window it moves with it. It follows the window's
/// resizes, and closes the paywall if the window closes under it.
final class PaywallOverlayWindow: PaywallHostWindow {
  private var parentObservers: [NSObjectProtocol] = []

  init(over parentWindow: NSWindow) {
    super.init(contentRect: Self.frame(over: parentWindow), styleMask: [.borderless])
    isOpaque = false
    backgroundColor = .clear
    hasShadow = false
    parentWindow.addChildWindow(self, ordered: .above)

    let center = NotificationCenter.default
    parentObservers = [
      center.addObserver(
        forName: NSWindow.didResizeNotification,
        object: parentWindow,
        queue: .main
      ) { [weak self, weak parentWindow] _ in
        guard let parentWindow = parentWindow else {
          return
        }
        self?.fit(to: Self.frame(over: parentWindow))
      },
      center.addObserver(
        forName: NSWindow.willCloseNotification,
        object: parentWindow,
        queue: .main
      ) { _ in
        Superwall.shared.paywallViewController?.dismiss(
          result: .declined,
          closeReason: .systemLogic
        )
      }
    ]
    makeKey()
  }

  deinit {
    parentObservers.forEach(NotificationCenter.default.removeObserver)
  }

  /// Taking key lets the paywall's text fields and keyboard shortcuts work.
  override var canBecomeKey: Bool {
    return true
  }

  override var canBecomeMain: Bool {
    return false
  }

  override func close() {
    parentObservers.forEach(NotificationCenter.default.removeObserver)
    parentObservers = []
    parent?.removeChildWindow(self)
    super.close()
  }

  /// The parent's content area in screen coordinates, leaving its title bar
  /// uncovered so the window can still be moved and closed.
  private static func frame(over parentWindow: NSWindow) -> NSRect {
    return parentWindow.convertToScreen(parentWindow.contentLayoutRect)
  }
}

/// Shows a paywall over the whole of the view it's presented from, which is
/// how the full screen, push and popup styles look on macOS. That view is
/// always one the SDK owns: the root of a ``PaywallOverlayWindow``, or of the
/// window made for an app that has none.
///
/// AppKit calls the paywall's appearance methods as its view joins and leaves
/// the window, so the paywall goes through the same lifecycle as it would in
/// a sheet.
final class PaywallOverlayAnimator: NSObject, NSViewControllerPresentationAnimator {
  enum Transition {
    /// No animation.
    case none
    /// Fades in and out. Used for popups, which scale their own content.
    case fade
    /// Rises from the bottom, as a full screen paywall does on iOS.
    case slideUp
    /// Slides in from the trailing edge, as a push does on iOS.
    case slideFromTrailingEdge
  }

  static let duration: TimeInterval = 0.35

  private let transition: Transition

  /// The leading, trailing, top and bottom constraints pinning the paywall to
  /// the view it covers. A slide moves the paywall by animating their constants.
  private var edgeConstraints: [NSLayoutConstraint] = []

  init(transition: Transition) {
    self.transition = transition
  }

  func animatePresentation(
    of viewController: NSViewController,
    from fromViewController: NSViewController
  ) {
    let containerView = fromViewController.view
    let overlayView = viewController.view
    overlayView.translatesAutoresizingMaskIntoConstraints = false
    containerView.addSubview(overlayView)
    edgeConstraints = [
      overlayView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
      overlayView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
      overlayView.topAnchor.constraint(equalTo: containerView.topAnchor),
      overlayView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
    ]
    NSLayoutConstraint.activate(edgeConstraints)

    guard transition != .none else {
      return
    }
    moveOffscreen(within: containerView.bounds)
    overlayView.alphaValue = transition == .fade ? 0 : 1
    containerView.layoutSubtreeIfNeeded()

    animate(in: containerView) {
      self.edgeConstraints.forEach { $0.animator().constant = 0 }
      overlayView.animator().alphaValue = 1
    }
  }

  func animateDismissal(
    of viewController: NSViewController,
    from fromViewController: NSViewController
  ) {
    let overlayView = viewController.view
    guard transition != .none else {
      overlayView.removeFromSuperview()
      return
    }
    let containerView = fromViewController.view
    animate(
      in: containerView,
      {
        self.moveOffscreen(within: containerView.bounds, animated: true)
        if self.transition == .fade {
          overlayView.animator().alphaValue = 0
        }
      },
      completion: {
        overlayView.removeFromSuperview()
        overlayView.alphaValue = 1
      }
    )
  }

  /// Offsets the paywall to where it slides in from and back to. A positive
  /// constant moves an edge towards the trailing edge or the bottom, so this
  /// is right in either layout direction.
  private func moveOffscreen(within bounds: CGRect, animated: Bool = false) {
    let horizontal: CGFloat
    let vertical: CGFloat
    switch transition {
    case .none,
      .fade:
      return
    case .slideUp:
      horizontal = 0
      vertical = bounds.height
    case .slideFromTrailingEdge:
      horizontal = bounds.width
      vertical = 0
    }
    for constraint in edgeConstraints {
      let isHorizontal = constraint.firstAttribute == .leading || constraint.firstAttribute == .trailing
      let constant = isHorizontal ? horizontal : vertical
      if animated {
        constraint.animator().constant = constant
      } else {
        constraint.constant = constant
      }
    }
  }

  private func animate(
    in containerView: NSView,
    _ animations: @escaping () -> Void,
    completion: (() -> Void)? = nil
  ) {
    NSAnimationContext.runAnimationGroup(
      { context in
        context.duration = Self.duration
        context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        context.allowsImplicitAnimation = true
        animations()
        containerView.layoutSubtreeIfNeeded()
      },
      completionHandler: completion
    )
  }
}
#endif
