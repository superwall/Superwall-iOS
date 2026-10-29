//
//  ContentView.swift
//  SuperwallMacExample
//
//  Created by Brian Anglin on 13/10/2026.
//

import SwiftUI
import SuperwallKit

struct ContentView: View {
  @EnvironmentObject private var eventLog: EventLog
  @State private var isPaywallViewPresented = false
  @State private var isCustomerCenterPresented = false

  var body: some View {
    HSplitView {
      actions
        .frame(minWidth: 320, maxWidth: 380)
      events
        .frame(minWidth: 320)
    }
    .sheet(isPresented: $isPaywallViewPresented) {
      PaywallView(
        placement: "non_gated_pro",
        onRequestDismiss: { _, _ in
          isPaywallViewPresented = false
        },
        feature: {
          eventLog.append("PaywallView feature unlocked")
        }
      )
      .frame(width: 480, height: 720)
    }
    .presentSuperwallCustomerCenter(isPresented: $isCustomerCenterPresented)
  }

  private var actions: some View {
    Form {
      Section("Placements") {
        Text(
          "Each button registers a placement added to a campaign on the Superwall dashboard. "
            + "If you're subscribed, a paywall won't show."
        )
        .font(.callout)
        .foregroundStyle(.secondary)
        Button("Launch Non-Gated Feature") {
          Superwall.shared.register(placement: "non_gated_pro") {
            eventLog.append("Feature unlocked: non_gated_pro")
          }
        }
        Button("Launch Gated Feature") {
          Superwall.shared.register(placement: "gated_pro") {
            eventLog.append("Feature unlocked: gated_pro")
          }
        }
      }

      Section("SwiftUI") {
        Button("Show PaywallView in a Sheet") {
          isPaywallViewPresented = true
        }
        Button("Show Customer Center Sheet") {
          isCustomerCenterPresented = true
        }
      }

      Section("Account") {
        Button("Present Customer Center") {
          Superwall.shared.presentCustomerCenter()
        }
        Button("Restore Purchases") {
          Task {
            let result = await Superwall.shared.restorePurchases()
            eventLog.append("Restore: \(result)")
          }
        }
        Button("Reset User") {
          Superwall.shared.reset()
        }
      }
    }
    .formStyle(.grouped)
  }

  private var events: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text("Events")
        .font(.headline)
        .padding(12)
      Divider()
      List(eventLog.entries) { entry in
        HStack(alignment: .firstTextBaseline) {
          Text(entry.date, style: .time)
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
          Text(entry.text)
            .font(.callout)
            .textSelection(.enabled)
        }
      }
    }
  }
}
