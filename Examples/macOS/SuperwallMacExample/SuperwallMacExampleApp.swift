//
//  SuperwallMacExampleApp.swift
//  SuperwallMacExample
//
//  Created by Brian Anglin on 13/10/2026.
//

import SwiftUI
import SuperwallKit

@main
struct SuperwallMacExampleApp: App {
  @StateObject private var eventLog = EventLog()

  init() {
    #warning("For your own app you will need to use your own API key, available from the Superwall Dashboard")
    let apiKey = "pk_e361c8a9662281f4249f2fa11d1a63854615fa80e15e7a4d"
    Superwall.configure(apiKey: apiKey)
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environmentObject(eventLog)
        .onAppear {
          Superwall.shared.delegate = eventLog
        }
        .onOpenURL { url in
          Superwall.handleDeepLink(url)
        }
    }
    .defaultSize(width: 760, height: 620)
  }
}

/// Collects the SDK's events so the example can show what happened.
@MainActor
final class EventLog: ObservableObject, SuperwallDelegate {
  struct Entry: Identifiable {
    let id = UUID()
    let date = Date()
    let text: String
  }

  @Published private(set) var entries: [Entry] = []

  func append(_ text: String) {
    entries.insert(Entry(text: text), at: 0)
  }

  nonisolated func handleSuperwallEvent(withInfo eventInfo: SuperwallEventInfo) {
    let description = eventInfo.event.description
    Task { @MainActor in
      self.append(description)
    }
  }

  nonisolated func subscriptionStatusDidChange(
    from oldValue: SubscriptionStatus,
    to newValue: SubscriptionStatus
  ) {
    Task { @MainActor in
      self.append("Subscription status: \(oldValue.description) → \(newValue.description)")
    }
  }
}
