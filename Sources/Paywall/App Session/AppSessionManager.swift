//
//  File.swift
//  
//
//  Created by Yusuf Tör on 04/05/2022.
//

import UIKit

class AppSessionManager {
  static let shared = AppSessionManager()
  var appSessionTimeout: Milliseconds?

  private(set) var appSession = AppSession() {
    didSet {
      SessionEventsManager.shared.updateAppSession()
    }
  }
  private let sessionEventsManager: SessionEventsManager
  private var lastAppClose: Date?
  private var didTrackLaunch = false

  /// Only directly initialise if testing otherwise use `AppSessionManager.shared`.
  init(sessionEventsManager: SessionEventsManager = SessionEventsManager.shared) {
    self.sessionEventsManager = sessionEventsManager
    addActiveStateObservers()
  }

  private func addActiveStateObservers() {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(applicationWillResignActive),
      name: UIApplication.willResignActiveNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(applicationDidBecomeActive),
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(applicationWillTerminate),
      name: UIApplication.willTerminateNotification,
      object: nil
    )
  }

  @objc private func applicationWillResignActive() {
    Paywall.track(SuperwallEvent.AppClose())
    lastAppClose = Date()
    appSession.endAt = Date()
  }

  @objc private func applicationWillTerminate() {
    appSession.endAt = Date()
  }

  @objc private func applicationDidBecomeActive() {
    let didStartNewSession = AppSessionLogic.didStartNewSession(
      lastAppClose,
      withSessionTimeout: appSessionTimeout
    )

    if didStartNewSession {
      appSession = AppSession()
      Paywall.track(SuperwallEvent.SessionStart())
    } else {
      appSession.endAt = nil
    }
    Paywall.track(SuperwallEvent.AppOpen())

    if !didTrackLaunch {
      Paywall.track(SuperwallEvent.AppLaunch())
      didTrackLaunch = true
    }

    Storage.shared.recordFirstSeenTracked()
  }
}
