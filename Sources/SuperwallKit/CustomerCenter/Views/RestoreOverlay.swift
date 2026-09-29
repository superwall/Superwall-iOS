//
//  RestoreOverlay.swift
//
//
//  Created by Jordan Morgan on 20/08/2026.
//

import SwiftUI

@available(iOS 15.0, *)
struct RestoreOverlay: View {
  @ObservedObject var viewModel: CustomerCenterViewModel
  @Environment(\.customerCenterStrings) private var strings
  @Environment(\.openURL) private var openURL

  var body: some View {
    ZStack {
      if viewModel.restoreState == .restoring {
        Color.black.opacity(0.25).ignoresSafeArea()
        VStack(spacing: 12) {
          ProgressView()
          Text(strings.string("customer_center_restoring")).font(.footnote)
        }
        .padding(24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityIdentifier("customer_center.restoring")
      }
    }
    .animation(.default, value: viewModel.restoreState)
    .alert(
      strings.string(alertTitleKey),
      isPresented: Binding(
        get: { viewModel.restoreState == .restored || viewModel.restoreState == .notFound },
        set: { if !$0 { viewModel.restoreState = .idle } }
      ),
      actions: {
        if viewModel.restoreState == .notFound {
          if viewModel.showsUpdateBanner, let url = viewModel.appStoreURL {
            Button(strings.string("customer_center_update_action")) { openURL(url) }
          }
          if let mail = viewModel.supportMailtoURL {
            Button(strings.string("customer_center_path_contact_support")) { openURL(mail) }
          }
        }
        Button(strings.string("customer_center_done"), role: .cancel) {}
      },
      message: {
        Text(strings.string(alertMessageKey))
      }
    )
  }

  private var alertTitleKey: String {
    viewModel.restoreState == .restored
      ? "customer_center_restore_success_title"
      : "customer_center_restore_none_title"
  }

  private var alertMessageKey: String {
    viewModel.restoreState == .restored
      ? "customer_center_restore_success_message"
      : "customer_center_restore_none_message"
  }
}
