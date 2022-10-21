//
//  File.swift
//  
//
//  Created by Yusuf Tör on 27/05/2022.
//

import UIKit
import Combine

protocol SessionEventsDelegate: AnyObject {
  var triggerSession: TriggerSessionManager { get }

  func enqueue(_ triggerSession: TriggerSession)
  func enqueue(_ triggerSessions: [TriggerSession])
  func enqueue(_ transaction: TransactionModel)
}

final class SessionEventsManager {
  /// The shared instance of the class
  static let shared = SessionEventsManager()

  /// The trigger session manager.
  lazy var triggerSession = TriggerSessionManager(delegate: self)

  /// The transaction manager.
  lazy var transactionRecorder = TransactionRecorder(delegate: self)

  /// A queue of trigger session events that get sent to the server.
  private let queue: SessionEventsQueue

  /// Network class. Can be injected via init for testing.
  private let network: Network

  /// Storage class. Can be injected via init for testing.
  private let storage: Storage

  /// Storage class. Can be injected via init for testing.
  private let configManager: ConfigManager

  private var cancellables: [AnyCancellable] = []


  /// Only instantiate this if you're testing. Otherwise use `SessionEvents.shared`.
  init(
    queue: SessionEventsQueue = SessionEventsQueue(),
    storage: Storage = .shared,
    network: Network = .shared,
    configManager: ConfigManager = .shared
  ) {
    self.queue = queue
    self.storage = storage
    self.network = network
    self.configManager = configManager

    Task {
      await postCachedSessionEvents()
    }
    addObservers()
  }

  /// App lifecycle observers that are passed to the trigger session manager.
  private func addObservers() {
    NotificationCenter.default
      .publisher(for: UIApplication.didEnterBackgroundNotification)
      .sink { [weak self] _ in
        guard let self = self else {
          return
        }
        Task {
          await self.triggerSession.didEnterBackground()
        }
      }
      .store(in: &cancellables)

    NotificationCenter.default
      .publisher(for: UIApplication.willEnterForegroundNotification)
      .sink { [weak self] _ in
        guard let self = self else {
          return
        }
        Task {
          await self.triggerSession.willEnterForeground()
        }
      }
      .store(in: &cancellables)

    NotificationCenter.default
      .publisher(for: UIApplication.willResignActiveNotification)
      .sink { [weak self] _ in
        guard let self = self else {
          return
        }
        Task {
          await self.queue.flushInternal()
          await self.queue.saveCacheToDisk()
        }
      }
      .store(in: &cancellables)
  }

  /// Gets the last 20 cached trigger sessions and transactions from the last time the app was terminated,
  /// sends them back to the server, then clears cache.
  private func postCachedSessionEvents() async {
    guard configManager.config?.featureFlags.enableSessionEvents == true else {
      return
    }
    let cachedTriggerSessions = storage.get(TriggerSessions.self) ?? []
    let cachedTransactions = storage.get(Transactions.self) ?? []

    if cachedTriggerSessions.isEmpty,
      cachedTransactions.isEmpty {
      return
    }

    let sessionEvents = SessionEventsRequest(
      triggerSessions: cachedTriggerSessions,
      transactions: cachedTransactions
    )

    await network.sendSessionEvents(sessionEvents)

    storage.clearCachedSessionEvents()
  }

  /// This only updates the app session in the trigger sessions.
  /// For transactions, the latest app session id is grabbed when the next transaction occurs.
  func updateAppSession(
    _ appSession: AppSession = AppSessionManager.shared.appSession
  ) async {
    await triggerSession.updateAppSession(to: appSession)
  }
}

// MARK: - SessionEventsDelegate
extension SessionEventsManager: SessionEventsDelegate {
  func enqueue(_ triggerSession: TriggerSession) {
    guard configManager.config?.featureFlags.enableSessionEvents == true else {
      return
    }
    Task {
      await queue.enqueue(triggerSession)
    }
  }

  func enqueue(_ triggerSessions: [TriggerSession]) {
    guard configManager.config?.featureFlags.enableSessionEvents == true else {
      return
    }
    Task {
      await queue.enqueue(triggerSessions)
    }
  }

  func enqueue(_ transaction: TransactionModel) {
    guard configManager.config?.featureFlags.enableSessionEvents == true else {
      return
    }
    Task {
      await queue.enqueue(transaction)
    }
  }
}
