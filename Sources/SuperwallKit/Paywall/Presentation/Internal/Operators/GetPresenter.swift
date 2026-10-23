//
//  File.swift
//  
//
//  Created by Yusuf Tör on 11/05/2023.
//
// swiftlint:disable strict_fileprivate

#if os(macOS)
import AppKit
#else
import UIKit
#endif
import Combine

struct PresentablePipelineOutput {
  let debugInfo: [String: Any]
  let paywallViewController: PaywallViewController
  let presenter: PlatformViewController
  let assignment: Assignment?
}

extension Superwall {
  /// Checks conditions for whether the paywall can present before accessing a window on
  /// which the paywall can present.
  ///
  /// - Parameters:
  ///   - paywallViewController: The ``PaywallViewController`` to present.
  ///   - audienceOutcome: The output from evaluating audience filters.
  ///   - request: The presentation request.
  ///   - debugInfo: Info used to print debug logs.
  ///   - paywallStatePublisher: A `PassthroughSubject` that gets sent ``PaywallState`` objects.
  ///
  /// - Returns: A `UIViewController`to present on.
  @discardableResult
  func getPresenterIfNecessary(
    for paywallViewController: PaywallViewController,
    audienceOutcome: AudienceFilterEvaluationOutcome,
    request: PresentationRequest,
    debugInfo: [String: Any],
    paywallStatePublisher: PassthroughSubject<PaywallState, Never>? = nil
  ) async throws -> PlatformViewController? {
    switch request.flags.type {
    case .getPaywall:
      await attemptTriggerFire(
        for: request,
        triggerResult: audienceOutcome.triggerResult
      )
      return nil
    case .handleImplicitTrigger,
      .paywallDeclineCheck,
      .getPresentationResult,
      .confirmAllAssignments:
      // We do not track trigger fire for these events (which would result in .paywall)
      return nil
    case .presentation:
      break
    }

    // Make sure there's a presenter. If there isn't throw an error if no paywall is being presented
    #if os(macOS)
    let presenter: PlatformViewController?
    if let providedViewController = request.presenter {
      presenter = providedViewController
    } else {
      presenter = await macPresenter()
    }
    #else
    if request.presenter == nil {
      await createPresentingWindowIfNeeded()
    }

    let providedViewController = request.presenter
    let rootViewController = await Superwall.shared.presentationItems.window?.rootViewController
    let presenter = providedViewController ?? rootViewController
    #endif

    guard let presenter = presenter else {
      Logger.debug(
        logLevel: .error,
        scope: .paywallPresentation,
        message: "No Presenter To Present Paywall",
        info: debugInfo
      )

      let error = InternalPresentationLogic.presentationError(
        domain: "SWKPresentationError",
        code: 103,
        title: "No UIViewController to present paywall on",
        value: "This usually happens when you call this method before a window was made key and visible."
      )
      let state: PaywallState = .presentationError(error)
      paywallStatePublisher?.send(state)
      paywallStatePublisher?.send(completion: .finished)
      throw PresentationPipelineError.noPresenter
    }

    await attemptTriggerFire(
      for: request,
      triggerResult: audienceOutcome.triggerResult
    )

    return presenter
  }

  func attemptTriggerFire(
    for request: PresentationRequest,
    triggerResult: InternalTriggerResult
  ) async {
    guard let placementName = request.presentationInfo.placementName else {
      // The paywall is being presented by identifier, which is what the debugger uses and that's not supported.
      return
    }
    switch request.presentationInfo {
    case .implicitTrigger,
      .explicitTrigger:
      switch triggerResult {
      case .error,
        .placementNotFound:
        return
      default:
        break
      }
    case .fromIdentifier:
      break
    }

    let triggerFire = InternalSuperwallEvent.TriggerFire(
      triggerResult: triggerResult,
      triggerName: placementName
    )
    await Superwall.shared.track(triggerFire)
  }

  #if os(macOS)
  /// What the app is showing on top, or a window of the SDK's own when the app
  /// has none, as a menu bar app might not.
  ///
  /// iOS covers the app with a window of its own every time. A Mac app's
  /// windows are its own to arrange, so the paywall attaches to them instead.
  @MainActor
  fileprivate func macPresenter() -> PlatformViewController? {
    if let topViewController = PlatformViewController.topMostViewController {
      return topViewController
    }
    if presentationItems.window == nil {
      let window = PaywallHostWindow(
        contentRect: NSRect(origin: .zero, size: PaywallSheetSize.fitting(nil)),
        styleMask: [.titled, .closable, .fullSizeContentView]
      )
      window.titlebarAppearsTransparent = true
      window.titleVisibility = .hidden
      window.delegate = presentationItems.windowDelegate
      window.center()
      presentationItems.window = window
    }
    presentationItems.window?.makeKeyAndOrderFront(nil)
    PlatformApplication.sharedApplication?.activate(ignoringOtherApps: true)
    return presentationItems.window?.rootViewController
  }

  @MainActor
  func destroyPresentingWindow() {
    presentationItems.window?.delegate = nil
    presentationItems.window?.close()
    presentationItems.window = nil
  }
  #else
  @MainActor
  fileprivate func createPresentingWindowIfNeeded() {
    guard presentationItems.window == nil else {
      return
    }
    guard let sharedApplication = PlatformApplication.sharedApplication else {
      return
    }
    let activeWindow = sharedApplication.activeWindow
    var presentingWindow: UIWindow?

    if let windowScene = activeWindow?.windowScene {
      presentingWindow = UIWindow(windowScene: windowScene)
    }

    presentingWindow?.rootViewController = UIViewController()
    presentationItems.window = presentingWindow
  }

  @MainActor
  func destroyPresentingWindow() {
    presentationItems.window?.windowScene = nil
    presentationItems.window = nil
  }
  #endif
}
