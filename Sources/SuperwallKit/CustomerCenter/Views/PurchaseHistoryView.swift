//
//  PurchaseHistoryView.swift
//
//
//  Created by Jordan Morgan on 20/08/2026.
//

import SwiftUI

@available(iOS 15.0, *)
struct PurchaseHistoryView: View {
  @ObservedObject var viewModel: CustomerCenterViewModel
  @Environment(\.customerCenterStrings) private var strings

  var body: some View {
    let sections = viewModel.historySections()
    List {
      historySection("customer_center_history_active", sections.active)
      historySection("customer_center_history_expired", sections.expired)
      historySection("customer_center_history_other", sections.other)
    }
    .listStyle(.insetGrouped)
    .navigationTitle(strings.string("customer_center_purchase_history"))
    .navigationBarTitleDisplayMode(.inline)
    .onAppear { viewModel.surfaceDidAppear() }
    .onDisappear { viewModel.surfaceDidDisappear() }
  }

  @ViewBuilder
  private func historySection(_ key: String, _ items: [PurchasePresentation]) -> some View {
    if !items.isEmpty {
      Section(strings.string(key)) {
        ForEach(items) { item in
          NavigationLink {
            PurchaseDetailRows(viewModel: viewModel, purchase: item)
          } label: {
            PurchaseCardView(purchase: item, refundResult: nil)
          }
        }
      }
    }
  }
}

@available(iOS 15.0, *)
struct PurchaseDetailRows: View {
  @ObservedObject var viewModel: CustomerCenterViewModel
  let purchase: PurchasePresentation
  @Environment(\.customerCenterStrings) private var strings
  private let dateFormatter: DateFormatter

  init(viewModel: CustomerCenterViewModel, purchase: PurchasePresentation) {
    self.viewModel = viewModel
    self.purchase = purchase
    // Dates must follow the same locale as the localized strings, not the system locale.
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    formatter.locale = viewModel.locale
    dateFormatter = formatter
  }

  var body: some View {
    List {
      Section {
        row(strings.string("customer_center_product_id"), purchase.productId ?? "—")
        if let date = purchase.purchaseDate {
          row(strings.string("customer_center_purchase_date"), dateFormatter.string(from: date))
        }
        if let date = purchase.expirationDate {
          row(strings.string("customer_center_expiration_date"), dateFormatter.string(from: date))
        }
        row(strings.string("customer_center_store"), purchase.storeLabelKey.map { strings.string($0) } ?? "App Store")
        if let sub = purchase.subscription {
          row(strings.string("customer_center_transaction_id"), sub.transactionId)
          if let offer = sub.offerType { row(strings.string("customer_center_offer"), offer.rawValue) }
        }
        if case .nonSubscription(let transaction) = purchase.kind {
          row(strings.string("customer_center_transaction_id"), transaction.transactionId)
        }
      }
      #if DEBUG
      Section("Debug") {
        row(strings.string("customer_center_sandbox"), String(ReceiptManager.isSandboxEnvironment ?? false))
      }
      #endif
    }
    .navigationTitle(purchase.title)
    .navigationBarTitleDisplayMode(.inline)
    .onAppear { viewModel.surfaceDidAppear() }
    .onDisappear { viewModel.surfaceDidDisappear() }
  }

  private func row(_ label: String, _ value: String) -> some View {
    HStack { Text(label); Spacer(); Text(value).foregroundStyle(.secondary).textSelection(.enabled) }
  }
}
