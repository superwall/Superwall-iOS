//
//  File.swift
//  
//
//  Created by Yusuf Tör on 04/05/2022.
//

import UIKit
import Combine

class AppSessionManager {
  static let shared = AppSessionManager()
  var appSessionTimeout: Milliseconds?

  private(set) var appSession = AppSession() {
    didSet {
      Task {
        await SessionEventsManager.shared.updateAppSession()
      }
    }
  }
  private let sessionEventsManager: SessionEventsManager
  private var lastAppClose: Date?
  private var didTrackLaunch = false
  private var cancellable: AnyCancellable?

  /// Only directly initialise if testing otherwise use `AppSessionManager.shared`.
  init(sessionEventsManager: SessionEventsManager = SessionEventsManager.shared) {
    self.sessionEventsManager = sessionEventsManager
    Task {
      await addActiveStateObservers()
    }
    listenForAppSessionTimeout()
  }

  @MainActor
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

  private func listenForAppSessionTimeout() {
    cancellable = ConfigManager.shared.$config
      .compactMap { $0 }
      .sink { [weak self] config in
        self?.appSessionTimeout = config.appSessionTimeout
      }
  }

  @objc private func applicationWillResignActive() {
    Task.detached(priority: .utility) {
      await Superwall.track(InternalSuperwallEvent.AppClose())
    }
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
      Task.detached(priority: .userInitiated) {
        await Superwall.track(InternalSuperwallEvent.SessionStart())
      }
    } else {
      appSession.endAt = nil
    }
    Task.detached(priority: .userInitiated) {
      await Superwall.track(InternalSuperwallEvent.AppOpen())
    }

    if !didTrackLaunch {
      Task.detached(priority: .userInitiated) {
        await Superwall.track(InternalSuperwallEvent.AppLaunch())
      }
      didTrackLaunch = true
    }

    Storage.shared.recordFirstSeenTracked()
  }
}
