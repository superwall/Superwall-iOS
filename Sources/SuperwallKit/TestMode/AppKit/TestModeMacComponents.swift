// Shared Test Mode controls on macOS.
#if os(macOS)
import AppKit
import SwiftUI

// MARK: - Shared Views

extension View {
  /// Rows in rounded groups, which `Form` has from macOS 13.
  @ViewBuilder
  func testModeGroupedForm() -> some View {
    if #available(macOS 13.0, *) {
      formStyle(.grouped)
    } else {
      self
    }
  }
}

struct LabeledRow<Content: View>: View {
  let label: String
  @ViewBuilder let content: () -> Content

  var body: some View {
    HStack {
      Text(label)
      Spacer()
      content()
    }
  }
}

/// The state, and offer type once there is one, chosen for an entitlement.
struct TestModeEntitlementPicker: View {
  let entitlementId: String
  @Binding var selection: EntitlementSelection

  private var stateOption: Binding<EntitlementStateOption> {
    Binding(
      get: {
        EntitlementStateOption.allCases.first { $0.subscriptionState == selection.state } ?? .inactive
      },
      set: { option in
        selection = EntitlementSelection(
          state: option.subscriptionState,
          offerType: option == .inactive ? nil : selection.offerType
        )
      }
    )
  }

  private var offerTypeOption: Binding<OfferTypeOption> {
    Binding(
      get: { OfferTypeOption.allCases.first { $0.offerType == selection.offerType } ?? .none },
      set: { option in
        selection = EntitlementSelection(state: selection.state, offerType: option.offerType)
      }
    )
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Picker(entitlementId, selection: stateOption) {
        ForEach(EntitlementStateOption.allCases, id: \.self) { option in
          Text(option.displayName).tag(option)
        }
      }
      if selection.state != nil {
        Picker("Offer", selection: offerTypeOption) {
          ForEach(OfferTypeOption.allCases, id: \.self) { option in
            Text(option.displayName).tag(option)
          }
        }
      }
    }
  }
}

/// The device or user attributes, read when first opened.
struct TestModeAttributesDisclosure: View {
  enum Source {
    case device
    case user
  }

  let title: String
  let source: Source
  @State private var isExpanded = false
  @State private var attributes: [(key: String, value: String)]?

  var body: some View {
    DisclosureGroup(title, isExpanded: $isExpanded) {
      if let attributes = attributes {
        ForEach(attributes, id: \.key) { attribute in
          HStack(alignment: .firstTextBaseline) {
            Text(attribute.key)
              .font(.caption.monospaced())
            Spacer()
            Text(attribute.value)
              .font(.caption)
              .foregroundStyle(.secondary)
              .textSelection(.enabled)
          }
        }
      } else {
        ProgressView()
      }
    }
    .onChange(of: isExpanded) { isExpanded in
      guard isExpanded, attributes == nil else {
        return
      }
      Task { await load() }
    }
  }

  @MainActor
  private func load() async {
    let values: [String: Any]
    switch source {
    case .device:
      values = await Superwall.shared.getDeviceAttributes()
    case .user:
      values = Superwall.shared.userAttributes
    }
    attributes = values.keys.sorted().map { key in
      (key: key, value: Self.format(values[key]))
    }
  }

  private static func format(_ value: Any?) -> String {
    switch value {
    case .none,
      is NSNull:
      return "null"
    case let string as String:
      return string
    // Before `NSNumber`, which a `Bool` bridges to.
    case let bool as Bool:
      return bool ? "true" : "false"
    case let number as NSNumber:
      return number.stringValue
    case let value?:
      return String(describing: value)
    }
  }
}
#endif
