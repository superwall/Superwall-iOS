//
//  PurchaseCardView.swift
//
//
//  Created by Jordan Morgan on 20/08/2026.
//

#if canImport(WebKit)
import SwiftUI

struct PurchaseCardView: View {
  let purchase: PurchasePresentation
  let refundResult: (productId: String, status: CustomerCenterRefundStatus)?
  @Environment(\.customerCenterStrings) private var strings
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  var body: some View {
    Group {
      // At accessibility text sizes the badge goes above the text column, so the column keeps the
      // card's full width and words and prices don't break mid-word.
      if dynamicTypeSize.isAccessibilitySize {
        VStack(alignment: .leading, spacing: 6) {
          badge
          details
        }
      } else {
        // The badge sits beside the text column rather than on a row of its own, so a card with
        // no title — a web product the catalogue hasn't named — doesn't open with an empty line.
        // The purchase is never hidden; only its title is allowed to be absent.
        HStack(alignment: .top) {
          details
          Spacer(minLength: 8)
          badge
        }
      }
    }
    .padding(.vertical, 4)
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier("customer_center.purchase.\(purchase.productId ?? purchase.id)")
  }

  private var badge: some View {
    BadgeView(badge: purchase.badge, rowId: purchase.productId ?? purchase.id)
  }

  private var details: some View {
    VStack(alignment: .leading, spacing: 6) {
      if purchase.isAwaitingCatalogue {
        // Skeletons for what the catalogue supplies: the name, the price, and a status line
        // that quotes the price. The sample text only sets each bar's length.
        placeholder("Subscription name", font: .headline)
        placeholder("$00.00 / month", font: .subheadline)
        if purchase.badge == .active {
          placeholder("Renews on 00 Month 0000 for $00.00", font: .subheadline)
        } else {
          Text(purchase.statusLine).font(.subheadline).foregroundStyle(Color.customerCenterSecondaryText)
        }
      } else {
        if let title = purchase.title { Text(title).font(.headline) }
        if let price = purchase.priceLine { Text(price).font(.subheadline) }
        Text(purchase.statusLine).font(.subheadline).foregroundStyle(Color.customerCenterSecondaryText)
      }
      if let key = purchase.storeLabelKey {
        Text(strings.string(key)).font(.caption).foregroundStyle(Color.customerCenterSecondaryText)
      }
      if let refundResult, refundResult.productId == purchase.productId {
        let isSuccess = refundResult.status == .success
        Text(strings.string(isSuccess ? "customer_center_refund_success" : "customer_center_refund_error"))
          .font(.caption)
          .foregroundStyle(isSuccess ? Color.customerCenterGreenText : Color.customerCenterRedText)
      }
    }
  }

  private func placeholder(_ sample: String, font: Font) -> some View {
    Text(sample)
      .font(font)
      .redacted(reason: .placeholder)
      .shimmering()
      .accessibilityHidden(true)
  }
}

struct BadgeView: View {
  let badge: PurchaseBadge
  var rowId: String?
  @Environment(\.customerCenterStrings) private var strings

  private var key: String {
    switch badge {
    case .active: return "customer_center_badge_active"
    case .freeTrial: return "customer_center_badge_free_trial"
    case .cancelled: return "customer_center_badge_cancelled"
    case .billingIssue: return "customer_center_badge_billing_issue"
    case .expired: return "customer_center_badge_expired"
    case .revoked: return "customer_center_badge_revoked"
    case .lifetime: return "customer_center_badge_lifetime"
    }
  }
  private var color: Color {
    switch badge {
    case .active, .lifetime: return .green
    case .freeTrial: return .orange
    case .cancelled, .billingIssue, .revoked: return .red
    case .expired: return .gray
    }
  }
  /// Text on the badge. The system colours are 2–2.9:1 on their own tint in light mode, and red
  /// and grey 3.4–3.5:1 on a dark sheet.
  private var textColor: Color {
    switch badge {
    case .active, .lifetime: return .customerCenterGreenText
    case .freeTrial: return .customerCenterOrangeText
    case .cancelled, .billingIssue, .revoked: return .customerCenterRedText
    case .expired: return .customerCenterGrayText
    }
  }
  var body: some View {
    Text(strings.string(key))
      .font(.caption2.weight(.semibold))
      .padding(.horizontal, 8)
      .padding(.vertical, 3)
      .background(color.opacity(0.15))
      .foregroundStyle(textColor)
      .clipShape(Capsule())
      .accessibilityIdentifier(rowId.map { "customer_center.badge.\(key).\($0)" } ?? "customer_center.badge.\(key)")
  }
}

extension Color {
  // Text versions of the badge colours, each at least 4.5:1 on its badge's 15% tint and on the
  // card, in both appearances, including the lighter card of a sheet in dark mode. Dark mode keeps
  // the system green and orange, which already pass.
  static let customerCenterGreenText = customerCenterDynamic(
    light: PlatformColor(hexString: "#207B37"),
    dark: .systemGreen
  )
  static let customerCenterOrangeText = customerCenterDynamic(
    light: PlatformColor(hexString: "#A15919"),
    dark: .systemOrange
  )
  static let customerCenterRedText = customerCenterDynamic(
    light: PlatformColor(hexString: "#C22B2E"),
    dark: PlatformColor(hexString: "#FF7779")
  )
  static let customerCenterGrayText = customerCenterDynamic(
    light: PlatformColor(hexString: "#6A6A6E"),
    dark: PlatformColor(hexString: "#A6A6AA")
  )
}
#endif
