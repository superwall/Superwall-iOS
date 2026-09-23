//
//  PurchaseCardView.swift
//
//
//  Created by Jordan Morgan on 20/08/2026.
//

import SwiftUI

@available(iOS 15.0, *)
struct PurchaseCardView: View {
  let purchase: PurchasePresentation
  let refundResult: (productId: String, status: CustomerCenterRefundStatus)?
  @Environment(\.customerCenterStrings) private var strings

  var body: some View {
    // The badge sits beside the text column rather than on a row of its own, so a card with no
    // title — a web product the catalogue hasn't named — doesn't open with an empty line. The
    // purchase is never hidden; only its title is allowed to be absent.
    HStack(alignment: .top) {
      VStack(alignment: .leading, spacing: 6) {
        if purchase.isAwaitingCatalogue {
          // Skeletons for what the catalogue supplies: the name, the price, and a status line
          // that quotes the price. The sample text only sets each bar's length.
          placeholder("Subscription name", font: .headline)
          placeholder("$00.00 / month", font: .subheadline)
          if purchase.badge == .active {
            placeholder("Renews on 00 Month 0000 for $00.00", font: .subheadline)
          } else {
            Text(purchase.statusLine).font(.subheadline).foregroundStyle(.secondary)
          }
        } else {
          if let title = purchase.title { Text(title).font(.headline) }
          if let price = purchase.priceLine { Text(price).font(.subheadline) }
          Text(purchase.statusLine).font(.subheadline).foregroundStyle(.secondary)
        }
        if let key = purchase.storeLabelKey {
          Text(strings.string(key)).font(.caption).foregroundStyle(.secondary)
        }
        if let refundResult, refundResult.productId == purchase.productId {
          let isSuccess = refundResult.status == .success
          Text(strings.string(isSuccess ? "customer_center_refund_success" : "customer_center_refund_error"))
            .font(.caption)
            .foregroundStyle(isSuccess ? Color.green : Color.red)
        }
      }
      Spacer(minLength: 8)
      BadgeView(badge: purchase.badge, rowId: purchase.productId ?? purchase.id)
    }
    .padding(.vertical, 4)
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier("customer_center.purchase.\(purchase.productId ?? purchase.id)")
  }

  private func placeholder(_ sample: String, font: Font) -> some View {
    Text(sample)
      .font(font)
      .redacted(reason: .placeholder)
      .accessibilityHidden(true)
  }
}

@available(iOS 15.0, *)
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
  var body: some View {
    Text(strings.string(key))
      .font(.caption2.weight(.semibold))
      .padding(.horizontal, 8)
      .padding(.vertical, 3)
      .background(color.opacity(0.15))
      .foregroundStyle(color)
      .clipShape(Capsule())
      .accessibilityIdentifier(rowId.map { "customer_center.badge.\(key).\($0)" } ?? "customer_center.badge.\(key)")
  }
}
