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
///
/// It hides the status bar when the app's window does, for the same reason: UIKit asks the
/// paywall's window whether to show it.
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

  /// The root of the app's window, unless this view controller is in that window itself.
  private var hostRootViewController: UIViewController? {
    guard
      let hostWindow = hostWindow,
      hostWindow !== viewIfLoaded?.window
    else {
      return nil
    }
    return hostWindow.rootViewController
  }

  /// The view controller that decides the orientations of the app's window.
  var hostViewController: UIViewController? {
    return hostRootViewController?.orientationDecidingViewController
  }

  /// The app's window may ask this one in turn, as an app that goes by the frontmost window
  /// does. It then answers for itself, so the two don't ask each other forever.
  override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
    guard
      !isAskingAboutOrientations,
      let hostViewController = hostViewController
    else {
      return super.supportedInterfaceOrientations
    }
    isAskingAboutOrientations = true
    defer { isAskingAboutOrientations = false }
    return hostViewController.supportedInterfaceOrientations
  }

  /// Whether this view controller is asking the app's window which orientations it allows.
  private var isAskingAboutOrientations = false

  #if !os(visionOS)
  /// The view controller that decides whether the app's window shows the status bar.
  var hostStatusBarViewController: UIViewController? {
    return hostRootViewController?.statusBarDecidingViewController
  }

  /// The app's window may ask this one in turn, as an app that goes by the frontmost window
  /// does. It then answers for itself, so the two don't ask each other forever.
  override var prefersStatusBarHidden: Bool {
    guard
      !isAskingAboutStatusBar,
      let hostStatusBarViewController = hostStatusBarViewController
    else {
      return super.prefersStatusBarHidden
    }
    isAskingAboutStatusBar = true
    defer { isAskingAboutStatusBar = false }
    return hostStatusBarViewController.hidesStatusBar
  }

  /// Whether this view controller is asking the app's window if the status bar is hidden.
  private var isAskingAboutStatusBar = false
  #endif

  /// Asks UIKit to check the app's orientations again once the paywall's window has gone, so the
  /// app returns to an orientation it allows.
  func updateHostOrientations() {
    if #available(iOS 16.0, *) {
      hostViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
    }
  }

  /// Asks UIKit to check the app's status bar, home indicator and screen edge gestures again once
  /// the paywall's window has gone. UIKit doesn't ask the app again by itself, so a status bar the
  /// app hides would stay on screen, and a home indicator it hides or edge swipes it holds back
  /// would stay as the paywall had them.
  func updateHostSystemUI() {
    #if !os(visionOS)
    hostStatusBarViewController?.setNeedsStatusBarAppearanceUpdate()
    hostViewController?.setNeedsUpdateOfHomeIndicatorAutoHidden()
    hostViewController?.setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
    #endif
  }
}

extension UIViewController {
  /// Whether this view controller was presented over the whole window, rather than as a sheet,
  /// popover or alert.
  ///
  /// This goes by the presentation style, not by what's on screen: on an iPhone in landscape a
  /// sheet covers the window too, but UIKit still doesn't ask it about orientation.
  var isPresentedFullScreen: Bool {
    if presentingViewController == nil {
      return false
    }
    switch modalPresentationStyle {
    case .fullScreen,
      .overFullScreen:
      return true
    case .custom:
      return presentationController?.shouldPresentInFullscreen ?? false
    default:
      return false
    }
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

#if !os(visionOS)
extension UIViewController {
  /// Whether UIKit asks this view controller about the status bar once it's presented, rather
  /// than the screen under it.
  ///
  /// These aren't the orientation rules. A view controller presented full screen is always
  /// asked, and so is one that covers its presenter when that's the whole window. A sheet,
  /// popover or overlay is asked only when it sets `modalPresentationCapturesStatusBarAppearance`.
  var takesStatusBarWhenPresented: Bool {
    guard let presentingViewController = presentingViewController else {
      return false
    }
    if modalPresentationCapturesStatusBarAppearance {
      return true
    }
    switch modalPresentationStyle {
    case .fullScreen:
      return true
    case .currentContext,
      .overCurrentContext:
      return presentingViewController.parent == nil
    default:
      return false
    }
  }

  /// The view controller UIKit asks about the window's status bar when this one is its root:
  /// the deepest presented view controller that takes the status bar.
  var statusBarDecidingViewController: UIViewController {
    var deciding = self
    var current = self
    while let presented = current.presentedViewController {
      if presented.takesStatusBarWhenPresented {
        deciding = presented
      }
      current = presented
    }
    return deciding
  }

  /// The view controller that decided the window's status bar before this one was presented
  /// on top: the nearest one at or below it that's the root or takes the status bar.
  var statusBarDecidingAncestor: UIViewController {
    var current = self
    while let presenting = current.presentingViewController,
      !current.takesStatusBarWhenPresented {
      current = presenting
    }
    return current
  }

  /// Whether this view controller hides the status bar, going by the child it hands the decision
  /// to, as UIKit does.
  ///
  /// It stops at a child it has already been through, so view controllers that hand the
  /// decision round in a circle don't keep it going forever.
  var hidesStatusBar: Bool {
    var deciding = self
    var visited: Set<ObjectIdentifier> = [ObjectIdentifier(self)]
    while let child = deciding.childForStatusBarHidden,
      visited.insert(ObjectIdentifier(child)).inserted {
      deciding = child
    }
    return deciding.prefersStatusBarHidden
  }
}
#endif
#endif
