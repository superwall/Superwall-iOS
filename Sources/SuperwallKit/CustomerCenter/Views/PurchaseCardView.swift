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
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Text(purchase.title).font(.headline)
        Spacer()
        BadgeView(badge: purchase.badge, rowId: purchase.productId ?? purchase.id)
      }
      if let price = purchase.priceLine { Text(price).font(.subheadline) }
      Text(purchase.statusLine).font(.subheadline).foregroundStyle(.secondary)
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
    .padding(.vertical, 4)
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier("customer_center.purchase.\(purchase.productId ?? purchase.id)")
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
