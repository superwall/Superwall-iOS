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

  private var subscriptions: [PurchasePresentation] { viewModel.purchases.filter(\.opensDetail) }
  private var others: [PurchasePresentation] { viewModel.purchases.filter { !$0.opensDetail } }

  var body: some View {
    List {
      if viewModel.showsUpdateBanner {
        AppUpdateWarningView(viewModel: viewModel)
      }
      if viewModel.showsDuplicateBanner {
        DuplicateSubscriptionBanner()
      }
      if !subscriptions.isEmpty {
        // Every subscription — and every entitlement-only purchase, see `opensDetail` — is a row
        // that opens its own detail screen, one or many alike. This screen keeps the actions that
        // apply to the account; anything that only makes sense against one purchase — change
        // plan, refund, cancel, the web management page — lives where the row leads.
        Section(strings.string("customer_center_section_subscriptions")) {
          ForEach(subscriptions) { purchase in
            CustomerCenterDrillDown {
              PurchaseDetailScreenView(viewModel: viewModel, purchase: purchase)
            } label: {
              PurchaseCardView(purchase: purchase, refundResult: viewModel.refundResult)
            }
          }
        }
      }
      if !others.isEmpty {
        Section(strings.string("customer_center_section_purchases")) {
          ForEach(others) { PurchaseCardView(purchase: $0, refundResult: nil) }
        }
      }
      Section(strings.string("customer_center_section_actions")) {
        PathsListView(viewModel: viewModel, purchase: nil)
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

  private var navigationTitle: String {
    viewModel.configuration.managementScreen.title ?? strings.string("customer_center_management_title")
  }
}

/// Detail for one subscription, reached by tapping its row on the management screen. Carries the
/// actions that only make sense against that subscription.
@available(iOS 15.0, *)
struct PurchaseDetailScreenView: View {
  @ObservedObject var viewModel: CustomerCenterViewModel
  let purchase: PurchasePresentation
  @Environment(\.customerCenterStrings) private var strings

  var body: some View {
    List {
      Section { PurchaseCardView(purchase: purchase, refundResult: viewModel.refundResult) }
      if viewModel.hasActions(for: purchase) {
        Section(strings.string("customer_center_section_actions")) {
          PathsListView(viewModel: viewModel, purchase: purchase, isScreenLevel: false)
        }
      } else {
        // The row opened this screen regardless — see `hasActions(for:)` — so say what there is
        // to say rather than head an empty list with "Actions".
        Section {
          Text(strings.string("customer_center_detail_nothing_to_manage"))
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("customer_center.detail.nothing_to_manage")
        }
      }
    }
    .listStyle(.insetGrouped)
    .navigationTitle(purchase.title ?? "")
    .navigationBarTitleDisplayMode(.inline)
    .onAppear { viewModel.surfaceDidAppear() }
    .onDisappear { viewModel.surfaceDidDisappear() }
  }
}
