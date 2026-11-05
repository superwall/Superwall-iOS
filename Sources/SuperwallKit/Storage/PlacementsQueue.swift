//
//  File.swift
//
//
//  Created by brian on 8/16/21.
//

import Foundation
import Combine

/// Sends n analytical events to the Superwall servers every 20 seconds, where n is defined by `maxEventCount`.
///
/// **Note**: this currently has a limit of 500 events per flush.
actor PlacementsQueue {
  /// Called once with whether the event reached Superwall. Events dropped from
  /// the queue before they're sent count as not reaching it.
  typealias DeliveryHandler = @Sendable (Bool) -> Void

  private struct QueuedEvent {
    let data: JSON
    let onDelivery: DeliveryHandler?
  }

  private let maxEventCount = 50
  private var elements: [QueuedEvent] = []
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
      .publisher(for: SystemInfo.applicationWillResignActiveNotification)
      .sink { [weak self] _ in
        Task {
          await self?.flushInternal()
        }
      }
  }

  /// Queues `data` for sending. Returns whether the tracking behavior allowed it.
  /// `onDelivery` is only called for queued events.
  @discardableResult
  func enqueue(
    data: JSON,
    from placement: Trackable,
    onDelivery: DeliveryHandler? = nil
  ) -> Bool {
    guard trackingAllowed(from: placement) else {
      return false
    }
    elements.append(QueuedEvent(data: data, onDelivery: onDelivery))
    return true
  }

  /// The names of the events waiting to be flushed. For tests.
  var queuedEventNames: [String] {
    elements.compactMap { $0.data["event_name"].string }
  }

  private func discardQueuedEvents() {
    let discarded = elements
    elements.removeAll()
    for event in discarded {
      event.onDelivery?(false)
    }
  }

  func setTrackingBehavior(_ behavior: EventTrackingBehavior) {
    trackingBehavior = behavior
    if behavior != .all {
      discardQueuedEvents()
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
      discardQueuedEvents()
      return
    }

    var eventsToSend: [QueuedEvent] = []

    var i = 0
    while i < maxEventCount && !elements.isEmpty {
      eventsToSend.append(elements.removeFirst())
      i += 1
    }

    if !eventsToSend.isEmpty {
      // Send to network
      let events = EventsRequest(events: eventsToSend.map { $0.data })
      let handlers = eventsToSend.compactMap { $0.onDelivery }
      Task { [network] in
        let isDelivered = await network.sendEvents(events: events)
        for handler in handlers {
          handler(isDelivered)
        }
      }
    }

    if !elements.isEmpty && depth > 0 {
      return flushInternal(depth: depth - 1)
    }
  }
}
