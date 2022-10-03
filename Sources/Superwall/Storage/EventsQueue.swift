//
//  File.swift
//  
//
//  Created by brian on 8/16/21.
//

import UIKit

/// Sends n analytical events to the Superwall servers every 20 seconds, where n is defined by `maxEventCount`.
///
/// **Note**: this currently has a limit of 500 events per flush.
final class EventsQueue {
  private let serialQueue = DispatchQueue(label: "me.superwall.eventQueue")
  private let maxEventCount = 50
  private var elements: [JSON] = []
  private var timer: Timer?

  deinit {
    timer?.invalidate()
    timer = nil
    NotificationCenter.default.removeObserver(self)
  }

  init() {
    let timeInterval = Superwall.options.networkEnvironment == .release ? 20.0 : 1.0
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
  }

  func enqueue(event: JSON) {
    serialQueue.async {
      self.elements.append(event)
    }
  }

  @objc private func flush() {
    serialQueue.async { [weak self] in
      guard let self = self else {
        return
      }
      self.flushInternal()
    }
  }

  private func flushInternal(depth: Int = 10) {
    var eventsToSend: [JSON] = []

    var i = 0
    while i < maxEventCount && !elements.isEmpty {
      eventsToSend.append(elements.removeFirst())
      i += 1
    }

    if !eventsToSend.isEmpty {
      // Send to network
      let events = EventsRequest(events: eventsToSend)
      Task { await Network.shared.sendEvents(events: events) }
    }

    if !elements.isEmpty && depth > 0 {
      return flushInternal(depth: depth - 1)
    }
  }
}
