//
//  File.swift
//  
//
//  Created by Yusuf Tör on 02/12/2022.
//

#if os(macOS)
import AppKit
#else
import UIKit
#endif
import Combine

final class PresentationItems: @unchecked Sendable {
  /// The publisher and request involved in the last successful paywall presentation request.
  var last: LastPresentationItems? {
    get {
      queue.sync { [weak self] in
        guard let self = self else {
          return nil
        }
        return self._last
      }
    }
    set {
      queue.async { [weak self] in
        self?._last = newValue
      }
    }
  }
  private var _last: LastPresentationItems?

  /// The ``PaywallInfo`` object stored from the last paywall view controller that was dismissed.
  var paywallInfo: PaywallInfo? {
    get {
      queue.sync { [weak self] in
        return self?._paywallInfo
      }
    }
    set {
      queue.async { [weak self] in
        self?._paywallInfo = newValue
      }
    }
  }
  private var _paywallInfo: PaywallInfo?

  /// The window that presents the paywall.
  ///
  /// On macOS this is an overlay child window, or a standalone window when
  /// the app has no window to show the paywall in.
  @MainActor
  var window: PlatformWindow?

  #if os(macOS)
  /// Closes the paywall when the window above is closed.
  let windowDelegate = PresentingWindowDelegate()
  #endif

  private let queue = DispatchQueue(label: "com.superwall.presentationitems")

  func reset() {
    queue.async { [weak self] in
      self?._last = nil
      self?._paywallInfo = nil
    }
  }
}

/// Items involved in the last successful paywall presentation request.
struct LastPresentationItems {
  /// The last paywall presentation request.
  let request: PresentationRequest

  /// The last state publisher.
  let statePublisher: PassthroughSubject<PaywallState, Never>

  /// The feature gating behavior of the previous paywall.
  let featureGatingBehavior: FeatureGatingBehavior
}

#if os(macOS)
/// Treats closing the window the SDK made for a paywall as closing the
/// paywall, so it's tracked as a manual close and can show a survey. The
/// window itself closes once the paywall has been dismissed.
final class PresentingWindowDelegate: NSObject, NSWindowDelegate {
  func windowShouldClose(_ sender: NSWindow) -> Bool {
    guard let paywallViewController = Superwall.shared.paywallViewController else {
      return true
    }
    paywallViewController.dismiss(
      result: .declined,
      closeReason: .manualClose
    )
    return false
  }
}
#endif
