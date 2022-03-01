//
//  File.swift
//  
//
//  Created by brian on 8/16/21.
//

import Foundation
import UIKit

let serialQueue = DispatchQueue(label: "me.superwall.eventQueue")
let maxEventCount = 50

final class EventsQueue {
  private var elements: [JSON] = []
  private var timer: Timer?

  init() {
    timer = Timer.scheduledTimer(
      timeInterval: Paywall.networkEnvironment == .release ? 20.0 : 1.0,
      target: self,
      selector: #selector(flush),
      userInfo: nil,
      repeats: true
    )
    let notificationCenter = NotificationCenter.default
    notificationCenter.addObserver(
      self,
      selector: #selector(flush),
      name: UIApplication.willResignActiveNotification,
      object: nil
    )
  }

  func addEvent(event: JSON) {
    serialQueue.async {
      self.elements.append(event)
    }
  }

  @objc func flush() {
    serialQueue.async {
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
      // Network.events(Network)
      Network.shared.events(events: EventsRequest(events: eventsToSend)) { _ in
        // Logger.superwallDebug("Events Queue:", result)
      }
    }

    if !elements.isEmpty && depth > 0 {
      return flushInternal(depth: depth - 1)
    }
  }

  deinit {
    timer?.invalidate()
    timer = nil
    NotificationCenter.default.removeObserver(self)
  }
}
