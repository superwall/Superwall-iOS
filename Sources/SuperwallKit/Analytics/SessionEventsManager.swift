//
//  File.swift
//  
//
//  Created by Yusuf Tör on 27/05/2022.
//

import UIKit
import Combine

protocol SessionEventsDelegate: AnyObject {
  func enqueue(_ transaction: StoreTransaction) async
}

class SessionEventsManager {
  /// A queue of transaction events that get sent to the server.
  private let queue: SessionEnqueuable

  private var cancellables: [AnyCancellable] = []

  private unowned let network: Network
  private unowned let storage: Storage
  private unowned let configManager: ConfigManager

  init(
    queue: SessionEnqueuable,
    storage: Storage,
    network: Network,
    configManager: ConfigManager
  ) {
    self.queue = queue
    self.storage = storage
    self.network = network
    self.configManager = configManager

    Task {
      await postCachedSessionEvents()
    }
  }

  /// Gets the last 20 cached transactions from the last time the app was terminated,
  /// sends them back to the server, then clears cache.
  private func postCachedSessionEvents() async {
    guard configManager.config?.featureFlags.enableSessionEvents == true else {
      return
    }
    let cachedTransactions = storage.get(Transactions.self) ?? []

    if cachedTransactions.isEmpty {
      return
    }

    let sessionEvents = SessionEventsRequest(
      transactions: cachedTransactions
    )

    await network.sendSessionEvents(sessionEvents)

    storage.clearCachedSessionEvents()
  }
}

// MARK: - SessionEventsDelegate
extension SessionEventsManager: SessionEventsDelegate {
  func enqueue(_ transaction: StoreTransaction) async {
    guard configManager.config?.featureFlags.enableSessionEvents == true else {
      return
    }
    await queue.enqueue(transaction)
  }
}
