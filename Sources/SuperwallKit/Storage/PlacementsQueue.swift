//
//  File.swift
//
//
//  Created by brian on 8/16/21.
//

import UIKit
import Combine

/// Sends n analytical events to the Superwall servers every 20 seconds, where n is defined by `maxEventCount`.
///
/// **Note**: this currently has a limit of 500 events per flush.
actor PlacementsQueue {
  private let maxEventCount = 50
  private var elements: [JSON] = []
  private var timer: Timer?
  private unowned let network: Network
  private var trackingBehavior: EventTrackingBehavior
  private let timerInterval: Double

  @MainActor
  private var resignActiveObserver: AnyCancellable?

  deinit {
    timer?.invalidate()
    timer = nil
  }

  init(
    network: Network,
    configManager: ConfigManager
  ) {
    self.network = network
    // Capture synchronously while configManager is guaranteed alive.
    self.trackingBehavior = configManager.options.eventTrackingBehavior
    switch configManager.options.networkEnvironment {
    case .release:
      self.timerInterval = 20.0
    default:
      self.timerInterval = 1.0
    }
    Task { [weak self] in
      await self?.setupTimer()
      await self?.addObserver()
    }
  }

  private func setupTimer() {
    let timer = Timer(
      timeInterval: timerInterval,
      repeats: true
    ) { [weak self] _ in
      guard let self = self else {
        return
      }
      Task {
        await self.flushInternal()
      }
    }
    self.timer = timer
    RunLoop.main.add(timer, forMode: .default)
  }

  @MainActor
  private func addObserver() async {
    resignActiveObserver = NotificationCenter.default
      .publisher(for: UIApplication.willResignActiveNotification)
      .sink { [weak self] _ in
        Task {
          await self?.flushInternal()
        }
      }
  }

  func enqueue(
    data: JSON,
    from placement: Trackable
  ) {
    guard trackingAllowed(from: placement) else {
      return
    }
    elements.append(data)
  }

  func setTrackingBehavior(_ behavior: EventTrackingBehavior) {
    trackingBehavior = behavior
    if behavior != .all {
      elements.removeAll()
    }
  }

  private func trackingAllowed(from placement: Trackable) -> Bool {
    switch trackingBehavior {
    case .all:
      return true
    case .superwallOnly:
      if placement is InternalSuperwallEvent.TriggerFire
        || placement is InternalSuperwallEvent.UserAttributes
        || placement is UserInitiatedPlacement.Track {
        return false
      }
      return true
    case .none:
      return false
    }
  }

  func flushInternal(depth: Int = 10) {
    if trackingBehavior == .none {
      elements.removeAll()
      return
    }

    var eventsToSend: [JSON] = []

    var i = 0
    while i < maxEventCount && !elements.isEmpty {
      eventsToSend.append(elements.removeFirst())
      i += 1
    }

    if !eventsToSend.isEmpty {
      // Send to network
      let events = EventsRequest(events: eventsToSend)
      Task { await network.sendEvents(events: events) }
    }

    if !elements.isEmpty && depth > 0 {
      return flushInternal(depth: depth - 1)
    }
  }
}
