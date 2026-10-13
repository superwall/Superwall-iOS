//
//  TeleportReturnCover.swift
//  SuperwallKit
//
// swiftlint:disable file_length type_body_length

import UIKit
import WebKit

extension Notification.Name {
  /// A Superwall return link (`scheme://superwall/return`) opened the app.
  static let superwallReturnLinkOpened = Notification.Name("SuperwallReturnLinkOpened")
}

/// Decides what the user sees of a teleport's waiting screen as they leave the app for the
/// browser and come back.
///
/// The waiting screen has to be in place when they switch back by hand, so it must already be in
/// the snapshot iOS takes when the app leaves. But iOS also shows that snapshot while the app comes
/// back, however it comes back, and a user who returns through the return link, having finished or
/// left the web flow, must never see the screen. A webview paints nothing in the background, so:
/// - leaving, the page draws the screen under a still of the paywall, which comes off once the app
///   is in the background, so the app switcher shows the screen;
/// - in the background, where the page cannot run, the teleport is checked here. Once it is
///   settled, a picture of the paywall without the screen covers it and iOS retakes the snapshot;
/// - just before iOS suspends the app, nothing settled yet, it covers the screen the same way. A
///   return link can arrive at any time after that, and iOS can no longer be asked to retake the
///   snapshot then. The app switcher shows the paywall from then on;
/// - a return link covers it before the first frame, whatever else happened.
/// Back in the app, through the return link or settled, the page removes the screen and the cover
/// comes off. Back by hand with the teleport still open, the cover fades and shows the screen.
///
/// The page's `showTeleportWaitingScreen` and `handleTeleportReturn` were first named
/// `showCheckoutWaitingScreen` and `hideCheckoutWaitingScreen`; pages built before the rename only
/// have the old names, so each call falls back to them.
@MainActor
final class TeleportReturnCover: NSObject {
  static let showWaitingScreenScript = """
    return await (window.app?.showTeleportWaitingScreen?.()
      ?? window.app?.showCheckoutWaitingScreen?.()) ?? false
    """
  static let returnScript = """
    return await (window.app?.handleTeleportReturn?.({ reason })
      ?? window.app?.hideCheckoutWaitingScreen?.({ reason })) ?? false
    """

  /// What the page hands over to check its teleport while the waiting screen is up.
  struct Watch: Equatable {
    let teleportId: String
    let teleportStatusUrl: URL
    /// Where a checkout the teleport led to is read. Nil for a web flow without a checkout.
    let checkoutStatusUrl: URL?
    let publicApiKey: String
  }

  /// Why the waiting screen is covered.
  private enum Reason {
    /// The teleport settled while the app was in the background.
    case settled
    /// The return link opened the app.
    case returnLink
    /// The app was about to be suspended. The teleport may still be open.
    case suspending
  }

  /// How long each step waits. Tests shorten these.
  struct Timing {
    /// How long leaving waits for the page to draw the waiting screen.
    var drawWait: UInt64 = 500_000_000
    /// How long the still stays up when the app does not leave (the browser did not open).
    var stillTimeout: UInt64 = 2_000_000_000
    /// The longest the teleport is checked in the background.
    var backgroundCheckLimit: TimeInterval = 25
    /// How much background time is kept to cover the screen and have iOS retake the snapshot.
    var suspendLead: TimeInterval = 4
    var backgroundCheckInterval: UInt64 = 1_000_000_000
    /// How long the app keeps running once it asked iOS to retake the snapshot.
    var snapshotLinger: UInt64 = 1_000_000_000
    /// How long a return by hand waits for a return link before showing the screen again. Some
    /// apps hand the link over only after the app is active.
    var revealGrace: UInt64 = 350_000_000
    var revealDuration: TimeInterval = 0.25
  }

  /// What the cover asks of iOS and the network. Tests stand these in.
  struct Environment {
    var applicationState: @MainActor () -> UIApplication.State = {
      UIApplication.sharedApplication?.applicationState ?? .active
    }
    var isSettled: (Watch) async -> Bool = TeleportStatusCheck.isSettled
    var makeStill: @MainActor (UIView) -> UIView? = { $0.snapshotView(afterScreenUpdates: false) }
    /// Nil when there is no application to ask for background time.
    var beginBackgroundTask: @MainActor (
      @escaping @Sendable () -> Void
    ) -> UIBackgroundTaskIdentifier? = { handler in
      UIApplication.sharedApplication?.beginBackgroundTask(
        withName: "Superwall teleport",
        expirationHandler: handler
      )
    }
    var endBackgroundTask: @MainActor (UIBackgroundTaskIdentifier) -> Void = {
      UIApplication.sharedApplication?.endBackgroundTask($0)
    }
    var backgroundTimeRemaining: @MainActor () -> TimeInterval = {
      UIApplication.sharedApplication?.backgroundTimeRemaining ?? 0
    }
    /// Where the app lifecycle and return link notifications arrive.
    var notificationCenter: NotificationCenter = .default
  }

  private let timing: Timing
  private let environment: Environment

  private weak var view: UIView?
  private weak var webView: WKWebView?
  private var leavingStill: UIView?
  private var pendingOpen: (id: UUID, open: () -> Void)?
  /// The paywall as it was before the waiting screen went up.
  private var paywallPicture: UIImage?
  private var watch: Watch?
  private var returnCover: (view: UIView, reason: Reason)?
  /// Why the return link brought the user back, as the page put it in the link.
  private var returnReason: String?
  private var uncovering: UUID?
  private var revealing: UUID?
  private var backgroundCheck: Task<Void, Never>?
  private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

  /// Whether a picture of the paywall is over the waiting screen.
  var isCovering: Bool {
    returnCover != nil
  }

  /// The cover's opacity, for tests of the fade.
  var coverAlpha: CGFloat? {
    returnCover?.view.alpha
  }

  init(
    view: UIView,
    webView: WKWebView,
    timing: Timing = Timing(),
    environment: Environment = Environment()
  ) {
    self.view = view
    self.webView = webView
    self.timing = timing
    self.environment = environment
    super.init()
    let center = environment.notificationCenter
    // Called synchronously: iOS takes the snapshot as soon as these observers return.
    center.addObserver(
      self,
      selector: #selector(appDidEnterBackground),
      name: UIApplication.didEnterBackgroundNotification,
      object: nil
    )
    center.addObserver(
      self,
      selector: #selector(appWillEnterForeground),
      name: UIApplication.willEnterForegroundNotification,
      object: nil
    )
    center.addObserver(
      self,
      selector: #selector(appDidBecomeActive),
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )
    center.addObserver(
      self,
      selector: #selector(returnLinkOpened),
      name: .superwallReturnLinkOpened,
      object: nil
    )
  }

  /// Has the page draw its waiting screen under a still of the paywall, then calls `open`.
  func leave(drawingWaitingScreen: Bool, open: @escaping () -> Void) {
    guard
      drawingWaitingScreen,
      #available(iOS 14.0, *),
      let view,
      let webView,
      let still = environment.makeStill(view)
    else {
      open()
      return
    }
    removeLeavingStill()
    paywallPicture = UIGraphicsImageRenderer(bounds: view.bounds).image { _ in
      view.drawHierarchy(in: view.bounds, afterScreenUpdates: false)
    }
    still.frame = view.bounds
    still.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    view.addSubview(still)
    leavingStill = still

    let id = UUID()
    pendingOpen = (id, open)
    webView.callAsyncJavaScript(
      Self.showWaitingScreenScript,
      arguments: [:],
      in: nil,
      in: .page
    ) { [weak self] _ in
      Task { @MainActor in
        self?.open(id)
      }
    }
    Task { @MainActor [weak self, timing] in
      try? await Task.sleep(nanoseconds: timing.drawWait)
      self?.open(id)
    }
  }

  func startWatching(_ watch: Watch) {
    self.watch = watch
  }

  func stopWatching() {
    watch = nil
    stopBackgroundCheck()
  }

  /// The paywall is gone: nothing of a teleport stays over it.
  func reset() {
    removeLeavingStill()
    removeCover()
    pendingOpen = nil
    paywallPicture = nil
    stopWatching()
  }

  private func open(_ id: UUID) {
    guard let pending = pendingOpen, pending.id == id else {
      return
    }
    pendingOpen = nil
    pending.open()
    Task { @MainActor [weak self, timing] in
      try? await Task.sleep(nanoseconds: timing.stillTimeout)
      guard let self, environment.applicationState() == .active else {
        return
      }
      self.removeLeavingStill()
    }
  }

  private func removeLeavingStill() {
    leavingStill?.removeFromSuperview()
    leavingStill = nil
  }

  // MARK: - App lifecycle

  @objc private func appDidEnterBackground() {
    if leavingStill != nil {
      removeLeavingStill()
      // Commit now, so the snapshot shows the waiting screen rather than the still.
      CATransaction.flush()
    }
    if watch != nil, paywallPicture != nil, returnCover == nil {
      checkInBackground()
    }
  }

  @objc private func appWillEnterForeground() {
    stopBackgroundCheck()
  }

  @objc private func appDidBecomeActive() {
    guard let returnCover else {
      return
    }
    switch returnCover.reason {
    case .settled,
      .returnLink:
      uncover()
    case .suspending:
      revealAfterGrace()
    }
  }

  @objc private func returnLinkOpened(_ notification: Notification) {
    returnReason = notification.userInfo?["reason"] as? String
    guard watch != nil || returnCover != nil else {
      // No waiting screen to cover, but the page still has to know the user is back: it
      // checks the teleport for a while, then treats an unfinished one as abandoned.
      tellPageOfReturn()
      return
    }
    Logger.debug(
      logLevel: .debug,
      scope: .paywallViewController,
      message: "Teleport: return link opened, covering the waiting screen"
    )
    if let returnCover {
      self.returnCover = (returnCover.view, .returnLink)
    } else {
      cover(.returnLink)
    }
    guard returnCover != nil else {
      // No picture of the paywall to cover with (the page reloaded since it left).
      tellPageOfReturn()
      return
    }
    if environment.applicationState() == .active {
      uncover()
    }
  }

  // MARK: - Background check

  private func checkInBackground() {
    stopBackgroundCheck()
    Logger.debug(
      logLevel: .debug,
      scope: .paywallViewController,
      message: "Teleport: checking the teleport while the app is in the background"
    )
    // Out of time before the check finished: cover the screen while iOS still listens. iOS
    // calls this on the main thread and expects the task ended before it returns, so no hop.
    guard let task = environment.beginBackgroundTask({ [weak self] in
      MainActor.assumeIsolated {
        guard let self else {
          return
        }
        self.coverBeforeSuspending()
        self.stopBackgroundCheck()
      }
    }) else {
      return
    }
    backgroundTask = task
    // Leaves enough of the background time to cover the screen and have the snapshot retaken.
    let remaining = environment.backgroundTimeRemaining()
    let checkFor = min(timing.backgroundCheckLimit, max(0, remaining - timing.suspendLead))
    backgroundCheck = Task { @MainActor [weak self, timing] in
      let deadline = Date().addingTimeInterval(checkFor)
      while !Task.isCancelled, Date() < deadline {
        guard let watch = self?.watch else {
          break
        }
        if await self?.environment.isSettled(watch) ?? false {
          guard !Task.isCancelled else {
            break
          }
          Logger.debug(
            logLevel: .debug,
            scope: .paywallViewController,
            message: "Teleport: settled in the background, covering the waiting screen"
          )
          self?.cover(.settled)
          self?.refreshSnapshot()
          try? await Task.sleep(nanoseconds: timing.snapshotLinger)
          self?.endBackgroundTask()
          return
        }
        try? await Task.sleep(nanoseconds: timing.backgroundCheckInterval)
      }
      guard !Task.isCancelled else {
        return
      }
      self?.coverBeforeSuspending()
      try? await Task.sleep(nanoseconds: timing.snapshotLinger)
      self?.endBackgroundTask()
    }
  }

  /// iOS is about to suspend the app, and a return link that arrives after that would come back
  /// to a snapshot with the waiting screen in it. So the snapshot goes back to the paywall.
  private func coverBeforeSuspending() {
    guard watch != nil, returnCover == nil else {
      return
    }
    Logger.debug(
      logLevel: .debug,
      scope: .paywallViewController,
      message: "Teleport: suspending with the teleport open, covering the waiting screen"
    )
    cover(.suspending)
    refreshSnapshot()
  }

  private func stopBackgroundCheck() {
    backgroundCheck?.cancel()
    backgroundCheck = nil
    endBackgroundTask()
  }

  private func endBackgroundTask() {
    guard backgroundTask != .invalid else {
      return
    }
    environment.endBackgroundTask(backgroundTask)
    backgroundTask = .invalid
  }

  // MARK: - Cover

  private func cover(_ reason: Reason) {
    guard returnCover == nil, let view, let paywallPicture else {
      return
    }
    let cover = UIImageView(image: paywallPicture)
    cover.frame = view.bounds
    cover.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    view.addSubview(cover)
    returnCover = (cover, reason)
    CATransaction.flush()
  }

  private func removeCover() {
    returnCover?.view.removeFromSuperview()
    returnCover = nil
    returnReason = nil
    uncovering = nil
    revealing = nil
  }

  private func refreshSnapshot() {
    guard let session = view?.window?.windowScene?.session else {
      return
    }
    UIApplication.sharedApplication?.requestSceneSessionRefresh(session)
  }

  /// Has the page remove the waiting screen, then takes the cover off once that is painted.
  private func uncover() {
    guard let returnCover, uncovering == nil else {
      return
    }
    revealing = nil
    // A fade in progress (back by hand, then the return link) stops: the cover stays whole
    // until the page has taken the waiting screen down.
    returnCover.view.layer.removeAllAnimations()
    returnCover.view.alpha = 1
    let id = UUID()
    uncovering = id
    if #available(iOS 14.0, *), let webView {
      webView.callAsyncJavaScript(
        Self.returnScript,
        arguments: ["reason": returnReason ?? ""],
        in: nil,
        in: .page
      ) { [weak self] _ in
        Task { @MainActor in
          self?.finishUncovering(id)
        }
      }
    }
    Task { @MainActor [weak self, timing] in
      try? await Task.sleep(nanoseconds: timing.drawWait)
      self?.finishUncovering(id)
    }
  }

  private func finishUncovering(_ id: UUID) {
    guard uncovering == id else {
      return
    }
    removeCover()
    Logger.debug(
      logLevel: .debug,
      scope: .paywallViewController,
      message: "Teleport: waiting screen removed, cover off"
    )
  }
}

// MARK: - Coming back

private extension TeleportReturnCover {
  func tellPageOfReturn() {
    guard #available(iOS 14.0, *), let webView else {
      return
    }
    webView.callAsyncJavaScript(
      Self.returnScript,
      arguments: ["reason": returnReason ?? ""],
      in: nil,
      in: .page,
      completionHandler: nil
    )
    returnReason = nil
  }

  /// Back by hand with the teleport still open: the waiting screen is still the right thing to
  /// show, so the cover fades off it, unless a return link turns up first.
  func revealAfterGrace() {
    guard revealing == nil, uncovering == nil else {
      return
    }
    let id = UUID()
    revealing = id
    Task { @MainActor [weak self, timing] in
      try? await Task.sleep(nanoseconds: timing.revealGrace)
      guard let self, self.revealing == id else {
        return
      }
      // Whatever happens next, the next activation may try again.
      self.revealing = nil
      guard
        let returnCover = self.returnCover,
        returnCover.reason == .suspending,
        environment.applicationState() == .active
      else {
        return
      }
      // The cover is the paywall, so this reads as the waiting screen coming up over it.
      UIView.animate(
        withDuration: timing.revealDuration,
        delay: 0,
        options: [.curveEaseOut, .allowUserInteraction]
      ) {
        returnCover.view.alpha = 0
      } completion: { [weak self] finished in
        // A return link that arrived mid-fade took the cover over; it comes off with the page.
        guard
          let self,
          finished,
          self.uncovering == nil,
          self.returnCover?.view === returnCover.view
        else {
          return
        }
        self.removeCover()
      }
    }
  }
}

/// Reads a teleport's status from the background, where the paywall page cannot run.
enum TeleportStatusCheck {
  /// Completed or expired, or the checkout it led to paid: the waiting screen goes, and the user
  /// likely comes back through the return link.
  static func isSettled(_ watch: TeleportReturnCover.Watch) async -> Bool {
    guard let teleport = await post(
      watch.teleportStatusUrl,
      body: ["teleportId": watch.teleportId],
      publicApiKey: watch.publicApiKey
    ) else {
      return false
    }
    switch teleport["status"] as? String {
    case "completed",
      "expired":
      return true
    default:
      break
    }
    guard
      let checkoutStatusUrl = watch.checkoutStatusUrl,
      let checkoutId = teleport["checkoutContextId"] as? String,
      let checkout = await post(
        checkoutStatusUrl,
        body: ["checkoutId": checkoutId],
        publicApiKey: watch.publicApiKey
      )
    else {
      return false
    }
    return checkout["status"] as? String == "completed"
  }

  private static func post(
    _ url: URL,
    body: [String: String],
    publicApiKey: String
  ) async -> [String: Any]? {
    var request = URLRequest(url: url, timeoutInterval: 5)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(publicApiKey)", forHTTPHeaderField: "Authorization")
    request.httpBody = try? JSONSerialization.data(withJSONObject: body)
    return await withCheckedContinuation { continuation in
      URLSession.shared.dataTask(with: request) { data, response, _ in
        guard
          let data,
          (response as? HTTPURLResponse)?.statusCode == 200,
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
          continuation.resume(returning: nil)
          return
        }
        continuation.resume(returning: json)
      }
      .resume()
    }
  }
}
