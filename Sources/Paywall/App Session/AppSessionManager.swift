//
//  File.swift
//  
//
//  Created by Yusuf Tör on 04/05/2022.
//

import UIKit

final class AppSessionManager {
  static let shared = AppSessionManager()
  private(set) var appSession = AppSession() {
    didSet {
      TriggerSessionManager.shared.updateAppSession()
    }
  }
  private var lastAppClose: Date?
  private var didTrackLaunch = false

  private init() {
    addActiveStateObservers()
  }
 /* Context for how to end a paywall session
  *     1. on app close, add paywall_session to QUEUE and treat app close as paywall session end
  *     2. on paywall close, regardless of what paywall_session_end_at is currently set at, update it to the paywall close time
  *     3. be sure to test what happens during a transaction, as app leaves foreground in that scenario
  *     4. new paywall_session id gets created every paywall_open
  */

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
    // appSession.endAt = Date()
  }

  @objc private func applicationWillTerminate() {
    appSession.endAt = Date()
  }

  @objc private func applicationDidBecomeActive() {
    Paywall.track(SuperwallEvent.AppOpen())

    // TODO: default session end to infinity, but in config people can set the avg session length.
    let sessionDidStart = AppSessionLogic.sessionDidStart(lastAppClose)

    if sessionDidStart {
      // appSession.startAt = Date()
      // appSession.endAt = nil
      Paywall.track(SuperwallEvent.SessionStart())
    }/* else {
      appSession.endAt = nil
    }*/

    if !didTrackLaunch {
      Paywall.track(SuperwallEvent.AppLaunch())
      didTrackLaunch = true
    }

    Storage.shared.recordFirstSeenTracked()
  }
}
