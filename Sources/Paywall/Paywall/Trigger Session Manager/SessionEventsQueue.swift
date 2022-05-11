//
//  File.swift
//  
//
//  Created by Yusuf Tör on 06/05/2022.
//

import UIKit

/// Sends n analytical events to the Superwall servers every 20 seconds, where n is defined by `maxEventCount`.
///
/// **Note**: this currently has a limit of 500 events per flush.
final class SessionEventsQueue {
  private let serialQueue = DispatchQueue(label: "me.superwall.sessionEventQueue")
  private let maxEventCount = 50
  private var triggerSessions: [TriggerSession] = []
  private var timer: Timer?
  private lazy var lastTwentySessions = LimitedQueue<TriggerSession>(limit: 20)

  deinit {
    timer?.invalidate()
    timer = nil
    NotificationCenter.default.removeObserver(self)
  }

  init() {
    let timeInterval = Paywall.networkEnvironment == .release ? 20.0 : 1.0
    timer = Timer.scheduledTimer(
      timeInterval: timeInterval,
      target: self,
      selector: #selector(flush),
      userInfo: nil,
      repeats: true
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(flush),
      name: UIApplication.willResignActiveNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(saveLatestSessionsToDisk),
      name: UIApplication.willResignActiveNotification,
      object: nil
    )
  }

  func enqueue(_ triggerSession: TriggerSession) {
    serialQueue.async { [weak self] in
      guard let self = self else {
        return
      }
      self.triggerSessions.append(triggerSession)
      self.lastTwentySessions.enqueue(triggerSession)
    }
  }

  func enqueue(_ triggerSessions: [TriggerSession]) {
    serialQueue.async { [weak self] in
      guard let self = self else {
        return
      }
      self.triggerSessions += triggerSessions

      for session in triggerSessions {
        self.lastTwentySessions.enqueue(session)
      }
    }
  }

  @objc private func flush() {
    serialQueue.async {
      self.flushInternal()
    }
  }

  private func flushInternal(depth: Int = 10) {
    var triggerSessionsToSend: [TriggerSession] = []

    var i = 0
    while i < maxEventCount && !triggerSessions.isEmpty {
      triggerSessionsToSend.append(triggerSessions.removeFirst())
      i += 1
    }

    if !triggerSessionsToSend.isEmpty {
      // Send to network
      let sessionEvents = SessionEventsRequest(
        triggerSessions: triggerSessionsToSend
      )
      Network.shared.sendSessionEvents(sessionEvents)
    }

    if !triggerSessions.isEmpty && depth > 0 {
      return flushInternal(depth: depth - 1)
    }
  }

  @objc private func saveLatestSessionsToDisk() {
    let sessions = lastTwentySessions.getArray()
    Storage.shared.saveTriggerSessions(sessions)
  }
}
