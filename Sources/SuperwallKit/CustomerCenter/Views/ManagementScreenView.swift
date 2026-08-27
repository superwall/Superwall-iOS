//
//  ManagementScreenView.swift
//
//
//  Created by Jordan Morgan on 20/08/2026.
//

import SwiftUI

@available(iOS 15.0, *)
struct ManagementScreenView: View {
  @ObservedObject var viewModel: CustomerCenterViewModel
  @Environment(\.customerCenterStrings) private var strings
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  private var subscriptions: [PurchasePresentation] { viewModel.purchases.filter { $0.subscription != nil } }
  private var others: [PurchasePresentation] { viewModel.purchases.filter { $0.subscription == nil } }
  private var isSingle: Bool { viewModel.purchases.count == 1 }

  var body: some View {
    List {
      if viewModel.showsUpdateBanner {
        AppUpdateWarningView(viewModel: viewModel)
      }
      if viewModel.showsDuplicateBanner {
        DuplicateSubscriptionBanner()
      }
      if !subscriptions.isEmpty {
        Section(strings.string("customer_center_section_subscriptions")) {
          ForEach(subscriptions) { purchase in
            if isSingle {
              PurchaseCardView(purchase: purchase, refundResult: viewModel.refundResult)
            } else {
              NavigationLink {
                PurchaseDetailScreenView(viewModel: viewModel, purchase: purchase)
              } label: {
                PurchaseCardView(purchase: purchase, refundResult: viewModel.refundResult)
              }
            }
          }
        }
      }
      if !others.isEmpty {
        Section(strings.string("customer_center_section_purchases")) {
          ForEach(visibleOthers) { PurchaseCardView(purchase: $0, refundResult: nil) }
        }
      }
      Section(strings.string("customer_center_section_actions")) {
        PathsListView(viewModel: viewModel, purchase: isSingle ? viewModel.purchases.first : nil)
      }
      if viewModel.configuration.showsPurchaseHistory {
        Section {
          NavigationLink(strings.string("customer_center_see_all_purchases")) {
            PurchaseHistoryView(viewModel: viewModel)
          }
          .accessibilityIdentifier("customer_center.purchase_history")
        }
      }
      if viewModel.configuration.showsAccountDetails {
        AccountDetailsSection(viewModel: viewModel)
      }
    }
    .listStyle(.insetGrouped)
    // The update banner can arrive a beat after the screen does — its version comes from an App
    // Store lookup — so animate the insertion rather than letting a row appear from nowhere.
    .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: viewModel.showsUpdateBanner)
    .navigationTitle(navigationTitle)
    .navigationBarTitleDisplayMode(.inline)
  }

  /// Non-subscription purchases to show inline. Collapsing to the first few keeps the management
  /// screen scannable, but that's only acceptable while the rest stay reachable — with
  /// `showsPurchaseHistory` off there is no "See all purchases" row, so a cap would make anything
  /// past it unreachable rather than merely collapsed.
  var visibleOthers: [PurchasePresentation] {
    viewModel.configuration.showsPurchaseHistory ? Array(others.prefix(Self.inlineOthersLimit)) : others
  }

  private static let inlineOthersLimit = 2

  private var navigationTitle: String {
    viewModel.configuration.managementScreen.title ?? strings.string("customer_center_management_title")
  }
}

/// Detail for one purchase when the user has several.
@available(iOS 15.0, *)
struct PurchaseDetailScreenView: View {
  @ObservedObject var viewModel: CustomerCenterViewModel
  let purchase: PurchasePresentation
  @Environment(\.customerCenterStrings) private var strings

  var body: some View {
    List {
      Section { PurchaseCardView(purchase: purchase, refundResult: viewModel.refundResult) }
      Section(strings.string("customer_center_section_actions")) {
        PathsListView(viewModel: viewModel, purchase: purchase, isScreenLevel: false)
      }
    }
    .listStyle(.insetGrouped)
    .navigationTitle(purchase.title)
    .navigationBarTitleDisplayMode(.inline)
    .onAppear { viewModel.surfaceDidAppear(isPushed: true) }
    .onDisappear { viewModel.surfaceDidDisappear(isPushed: true) }
  }
}
