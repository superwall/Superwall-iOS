//
//  PresentingWindowRootViewController.swift
//  SuperwallKit
//

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

  /// The view controller on top of the app's window, which decides its orientations.
  var hostViewController: UIViewController? {
    guard
      let hostWindow = hostWindow,
      hostWindow !== viewIfLoaded?.window
    else {
      return nil
    }
    var topViewController = hostWindow.rootViewController
    while let presentedViewController = topViewController?.presentedViewController {
      topViewController = presentedViewController
    }
    return topViewController
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
