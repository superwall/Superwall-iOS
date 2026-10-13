//
//  TestModeMacSheets.swift
//  SuperwallKit
//
//  Created by Brian Anglin on 13/10/2026.
//
// The test mode modal, purchase drawer and restore drawer on macOS. They do
// what the UIKit ones do, built in SwiftUI and shown as sheets.

#if os(macOS)
import AppKit
import SwiftUI

// MARK: - Modal

/// Presents the test mode modal when a user is first detected as being in test mode.
enum TestModeModal {
  @MainActor
  static func present(
    reason: TestModeReason,
    userId: String,
    isIdentified: Bool,
    hasPurchaseController: Bool,
    availableEntitlements: [String],
    initialFreeTrialOverride: FreeTrialOverride,
    apiKey: String,
    networkEnvironment: SuperwallOptions.NetworkEnvironment,
    from viewController: NSViewController?
  ) async -> TestModeModalResult {
    let baseUrl = networkEnvironment.dashboardBaseUrl
    let userLinkURL = URL(string: "\(baseUrl)/sdk-link/applications/\(apiKey)/users/\(userId)")
    let savedSelections = TestModeSettingsStore.loadSelections()
      .filter { availableEntitlements.contains($0.key) && $0.value.state != nil }
    let freeTrialOverride = TestModeSettingsStore.loadFreeTrialOverride(
      fallback: initialFreeTrialOverride
    )

    return await withCheckedContinuation { continuation in
      TestModeSheetPresenter.present(
        size: CGSize(width: 460, height: 560),
        on: viewController,
        onCancel: {
          continuation.resume(returning: TestModeModalResult(
            entitlements: TestModeSettingsStore.entitlements(from: savedSelections),
            freeTrialOverride: freeTrialOverride
          ))
        },
        content: { close in
          TestModeModalView(
            reason: reason,
            userId: userId,
            isIdentified: isIdentified,
            hasPurchaseController: hasPurchaseController,
            availableEntitlements: availableEntitlements,
            userLinkURL: userLinkURL,
            selections: savedSelections,
            freeTrialOverride: freeTrialOverride
          ) { selections, freeTrialOverride in
            guard close() else { return }
            TestModeSettingsStore.save(selections, freeTrialOverride: freeTrialOverride)
            continuation.resume(
              returning: TestModeModalResult(
                entitlements: TestModeSettingsStore.entitlements(from: selections),
                freeTrialOverride: freeTrialOverride
              )
            )
          }
        }
      )
    }
  }
}

private struct TestModeModalView: View {
  let reason: TestModeReason
  let userId: String
  let isIdentified: Bool
  let hasPurchaseController: Bool
  let availableEntitlements: [String]
  let userLinkURL: URL?
  @State var selections: [String: EntitlementSelection]
  @State var freeTrialOverride: FreeTrialOverride
  let onOK: ([String: EntitlementSelection], FreeTrialOverride) -> Void

  var body: some View {
    VStack(spacing: 0) {
      VStack(spacing: 6) {
        Text("\u{1F9EA} Test Mode Active")
          .font(.title2.bold())
        Text(
          "\(reason.description).\nAll purchases will be simulated and "
            + "product data will be retrieved from the Superwall dashboard."
        )
        .font(.callout)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
      }
      .padding(20)

      Form {
        Section {
          LabeledRow(label: isIdentified ? "User ID" : "Alias ID") {
            HStack(spacing: 8) {
              Text(userId)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
              Button("Copy") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(userId, forType: .string)
              }
              if let userLinkURL = userLinkURL {
                Link("Dashboard", destination: userLinkURL)
              }
            }
          }
          LabeledRow(label: "Purchase Controller") {
            Text(hasPurchaseController ? "Provided (not used in Test Mode)" : "Not provided")
              .foregroundStyle(.secondary)
          }
          TestModeAttributesDisclosure(title: "Device Attributes", source: .device)
          TestModeAttributesDisclosure(title: "User Attributes", source: .user)
          Picker("Free Trial Override", selection: $freeTrialOverride) {
            ForEach(FreeTrialOverride.allCases, id: \.self) { option in
              Text(option.displayName).tag(option)
            }
          }
        }

        if !availableEntitlements.isEmpty {
          Section {
            ForEach(availableEntitlements, id: \.self) { entitlementId in
              TestModeEntitlementPicker(
                entitlementId: entitlementId,
                selection: selectionBinding(for: entitlementId)
              )
            }
          } header: {
            Text("Starting Entitlements")
          } footer: {
            Text("Select the state of existing entitlements.")
          }
        }
      }
      .testModeGroupedForm()

      HStack {
        Button("Reset to Defaults") {
          selections = [:]
          freeTrialOverride = .useDefault
          TestModeSettingsStore.clear()
        }
        Spacer()
        Button("OK") {
          onOK(selections, freeTrialOverride)
        }
        .keyboardShortcut(.defaultAction)
      }
      .padding(16)
    }
  }

  private func selectionBinding(for entitlementId: String) -> Binding<EntitlementSelection> {
    Binding(
      get: { selections[entitlementId] ?? EntitlementSelection(state: nil, offerType: nil) },
      set: { selection in
        if selection.state != nil {
          selections[entitlementId] = selection
        } else {
          selections.removeValue(forKey: entitlementId)
        }
      }
    )
  }
}

// MARK: - Purchase

/// Presents a sheet for test mode purchases instead of calling StoreKit.
///
/// Offers the same three outcomes as the iOS drawer: purchase, abandon and failure.
enum TestModePurchaseDrawer {
  @MainActor
  static func present(
    product: StoreProduct,
    entitlements: [String],
    showFreeTrial: Bool,
    from viewController: NSViewController,
    completion: @escaping (TestModePurchaseResult) -> Void
  ) {
    TestModeSheetPresenter.present(
      size: CGSize(width: 400, height: 420),
      on: viewController,
      onCancel: { completion(.abandoned) },
      content: { close in
        TestModePurchaseView(
          product: product,
          entitlements: entitlements,
          showFreeTrial: showFreeTrial
        ) { result in
          guard close() else { return }
          completion(result)
        }
      }
    )
  }
}

private struct TestModePurchaseView: View {
  let product: StoreProduct
  let entitlements: [String]
  let showFreeTrial: Bool
  let onFinish: (TestModePurchaseResult) -> Void

  private var priceText: String {
    let period = product.period
    return period.isEmpty ? product.localizedPrice : "\(product.localizedPrice) per \(period)"
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("\u{1F9EA} Test Mode")
        .font(.title3.weight(.semibold))

      GroupBox {
        VStack(alignment: .leading, spacing: 8) {
          Text("Product Identifier")
            .font(.caption)
            .foregroundStyle(.secondary)
          Text(product.productIdentifier)
            .font(.headline)
            .textSelection(.enabled)
          Divider()
          if showFreeTrial {
            Text("\(product.trialPeriodText) free trial")
              .font(.headline)
            Text("then")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          Text(priceText)
            .font(.headline)
          if product.period.isEmpty {
            Text("One-time charge")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          Divider()
          Text(entitlements.count == 1 ? "Unlocks Entitlement" : "Unlocks Entitlements")
            .font(.caption)
            .foregroundStyle(.secondary)
          Text(entitlements.isEmpty ? "No entitlements" : entitlements.joined(separator: ", "))
            .foregroundStyle(entitlements.isEmpty ? .secondary : .primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(4)
      }

      HStack {
        Button("Cancel") {
          onFinish(.abandoned)
        }
        .keyboardShortcut(.cancelAction)
        Button("Simulate Failure", role: .destructive) {
          onFinish(.failed)
        }
        Spacer()
        Button(showFreeTrial ? "Start Free Trial" : "Confirm Purchase") {
          onFinish(.purchased)
        }
        .keyboardShortcut(.defaultAction)
      }

      Text("This is a simulated purchase. No real transaction will occur.")
        .font(.caption)
        .foregroundStyle(.tertiary)
        .frame(maxWidth: .infinity)
    }
    .padding(20)
  }
}

// MARK: - Restore

/// Presents a sheet for test mode restores with entitlement selection.
enum TestModeRestoreDrawer {
  @MainActor
  static func present(
    availableEntitlements: [String],
    from viewController: NSViewController,
    completion: @escaping (TestModeRestoreResult) -> Void
  ) {
    TestModeSheetPresenter.present(
      size: CGSize(width: 420, height: 440),
      on: viewController,
      onCancel: { completion(.cancelled) },
      content: { close in
        TestModeRestoreView(availableEntitlements: availableEntitlements) { result in
          guard close() else { return }
          completion(result)
        }
      }
    )
  }
}

private struct TestModeRestoreView: View {
  let availableEntitlements: [String]
  let onFinish: (TestModeRestoreResult) -> Void
  @State private var selections: [String: EntitlementSelection] = [:]

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("\u{1F9EA} Test Mode")
        .font(.title3.weight(.semibold))
      Text("Simulate Restore")
        .font(.headline)
      Text("Select which entitlements you want to restore (if any):")
        .foregroundStyle(.secondary)

      Form {
        ForEach(availableEntitlements, id: \.self) { entitlementId in
          TestModeEntitlementPicker(
            entitlementId: entitlementId,
            selection: Binding(
              get: { selections[entitlementId] ?? EntitlementSelection(state: nil, offerType: nil) },
              set: { selection in
                if selection.state != nil {
                  selections[entitlementId] = selection
                } else {
                  selections.removeValue(forKey: entitlementId)
                }
              }
            )
          )
        }
      }
      .testModeGroupedForm()

      HStack {
        Button("Cancel") {
          onFinish(.cancelled)
        }
        .keyboardShortcut(.cancelAction)
        Spacer()
        Button("Restore") {
          onFinish(.restored(TestModeSettingsStore.entitlements(from: selections)))
        }
        .keyboardShortcut(.defaultAction)
      }

      Text("This is a simulated restore. No real transaction will occur.")
        .font(.caption)
        .foregroundStyle(.tertiary)
        .frame(maxWidth: .infinity)
    }
    .padding(20)
  }
}

#endif
