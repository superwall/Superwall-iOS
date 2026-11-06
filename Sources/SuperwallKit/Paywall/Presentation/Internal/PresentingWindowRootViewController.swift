//
//  PresentingWindowRootViewController.swift
//  SuperwallKit
//

#if canImport(WebKit) && !os(macOS)
import UIKit

/// The root of the window the SDK creates to present a paywall.
///
/// It takes its orientation rules from the app's own window, which it covers, so a paywall can't
/// rotate the app into an orientation the app doesn't allow. Apps that lock orientation in a view
/// controller rather than in their Info.plist, such as Unity games, depend on this: UIKit asks the
/// paywall's window, not the app's, which orientations are allowed.
final class PresentingWindowRootViewController: UIViewController {
  /// The app's window that was active when the paywall's window was created.
  private weak var hostWindow: UIWindow?

  init(hostWindow: UIWindow?) {
    self.hostWindow = hostWindow
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  /// The view controller that decides the orientations of the app's window.
  var hostViewController: UIViewController? {
    guard
      let hostWindow = hostWindow,
      hostWindow !== viewIfLoaded?.window
    else {
      return nil
    }
    return hostWindow.rootViewController?.orientationDecidingViewController
  }

  override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
    return hostViewController?.supportedInterfaceOrientations ?? super.supportedInterfaceOrientations
  }

  /// Asks UIKit to check the app's orientations again once the paywall's window has gone, so the
  /// app returns to an orientation it allows.
  func updateHostOrientations() {
    if #available(iOS 16.0, *) {
      hostViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
    }
  }
}

extension UIViewController {
  /// Whether this view controller was presented over the whole window, rather than as a sheet,
  /// popover or alert.
  var isPresentedFullScreen: Bool {
    if presentingViewController == nil {
      return false
    }
    return presentationController?.shouldPresentInFullscreen ?? false
  }

  /// The view controller UIKit asks for the window's orientations when this one is its root:
  /// the deepest view controller presented over the whole window. Sheets, popovers and alerts
  /// on top of it don't count.
  var orientationDecidingViewController: UIViewController {
    var deciding = self
    var current = self
    while let presented = current.presentedViewController {
      if presented.isPresentedFullScreen {
        deciding = presented
      }
      current = presented
    }
    return deciding
  }

  /// The view controller that decided the window's orientations before this one was presented
  /// on top: the nearest one at or below it that's the root or fills the window.
  var orientationDecidingAncestor: UIViewController {
    var current = self
    while let presenting = current.presentingViewController,
      !current.isPresentedFullScreen {
      current = presenting
    }
    return current
  }
}
#endif
