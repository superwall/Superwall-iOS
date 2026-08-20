//
//  CustomerCenterStubs.swift
//
//
//  Created by Claude on 20/08/2026.
//

import SwiftUI

// Stub — implemented in a later commit (Task 13: survey, history, account details,
// update banner, duplicate banner, restore overlay). These exist only so
// CustomerCenterView and friends build and the Task 12 smoke test passes.

@available(iOS 15.0, *)
struct RestoreOverlay: View {
  @ObservedObject var viewModel: CustomerCenterViewModel
  var body: some View { EmptyView() }
}

@available(iOS 15.0, *)
struct AppUpdateWarningView: View {
  @ObservedObject var viewModel: CustomerCenterViewModel
  var body: some View { Section { EmptyView() } }
}

@available(iOS 15.0, *)
struct DuplicateSubscriptionBanner: View {
  var body: some View { Section { EmptyView() } }
}

@available(iOS 15.0, *)
struct FeedbackSurveyView: View {
  @ObservedObject var viewModel: CustomerCenterViewModel
  var body: some View { EmptyView() }
}

@available(iOS 15.0, *)
struct PurchaseHistoryView: View {
  @ObservedObject var viewModel: CustomerCenterViewModel
  var body: some View { EmptyView() }
}

@available(iOS 15.0, *)
struct AccountDetailsSection: View {
  @ObservedObject var viewModel: CustomerCenterViewModel
  var body: some View { Section { EmptyView() } }
}
