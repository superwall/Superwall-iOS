//
//  CustomerCenterView.swift
//
//
//  Created by Claude on 20/08/2026.
//

import SwiftUI

/// Navigation behaviour of ``CustomerCenterView``.
@available(iOS 15.0, *)
public struct CustomerCenterNavigationOptions {
  /// `true` when you push the view inside your own navigation stack (no wrapping `NavigationView`).
  public var usesExistingNavigation: Bool
  /// Shows a close button in the trailing toolbar position.
  public var showsCloseButton: Bool
  /// Called when the close button is tapped. `nil` uses the environment dismiss action.
  public var onClose: (() -> Void)?

  /// Creates navigation options for ``CustomerCenterView``.
  /// - Parameters:
  ///   - usesExistingNavigation: `true` when you push the view inside your own navigation stack.
  ///   - showsCloseButton: Shows a close button in the trailing toolbar position.
  ///   - onClose: Called when the close button is tapped. `nil` uses the environment dismiss action.
  public init(
    usesExistingNavigation: Bool = false,
    showsCloseButton: Bool = true,
    onClose: (() -> Void)? = nil
  ) {
    self.usesExistingNavigation = usesExistingNavigation
    self.showsCloseButton = showsCloseButton
    self.onClose = onClose
  }

  /// The default navigation options: wraps in its own `NavigationView` and shows a close button.
  public static let `default` = CustomerCenterNavigationOptions()
}

/// A self-service screen where users can view and manage their subscriptions and purchases.
@available(iOS 15.0, *)
public struct CustomerCenterView: View {
  @StateObject private var viewModel: CustomerCenterViewModel
  private let navigationOptions: CustomerCenterNavigationOptions
  @Environment(\.dismiss) private var dismiss
  @Environment(\.colorScheme) private var colorScheme

  /// Creates a Customer Center view.
  /// - Parameters:
  ///   - configuration: Overrides ``SuperwallOptions/customerCenter``. `nil` uses the options value.
  ///   - navigationOptions: How the view integrates with navigation.
  public init(
    configuration: CustomerCenterConfiguration? = nil,
    navigationOptions: CustomerCenterNavigationOptions = .default
  ) {
    let model = CustomerCenterManager.makeViewModel(configuration: configuration)
    model.presentationMode = navigationOptions.usesExistingNavigation ? "embedded" : "sheet"
    _viewModel = StateObject(wrappedValue: model)
    self.navigationOptions = navigationOptions
  }

  init(viewModel: CustomerCenterViewModel, navigationOptions: CustomerCenterNavigationOptions) {
    _viewModel = StateObject(wrappedValue: viewModel)
    self.navigationOptions = navigationOptions
  }

  public var body: some View {
    Group {
      if navigationOptions.usesExistingNavigation {
        content
      } else {
        NavigationView { content }.navigationViewStyle(.stack)
      }
    }
    .environment(\.customerCenterStrings, viewModel.strings)
    .environment(\.customerCenterTheme, theme)
    .task { await viewModel.load() }
    .onDisappear { viewModel.dismiss() }
  }

  private var content: some View {
    screenContent
      .customerCenterSheets(viewModel: viewModel)
      .tint(themeAccent)
  }

  // `ToolbarContentBuilder`'s conditional (`if`) support needs iOS 16, so the close button is
  // toggled here at the plain `@ViewBuilder` level instead, which iOS 15 supports.
  @ViewBuilder
  private var screenContent: some View {
    if navigationOptions.showsCloseButton {
      coreContent.toolbar { closeButtonToolbarItem }
    } else {
      coreContent
    }
  }

  private var coreContent: some View {
    ZStack {
      switch viewModel.state {
      case .loading:
        ProgressView().accessibilityIdentifier("customer_center.loading")
      case .management:
        ManagementScreenView(viewModel: viewModel)
      case .noActive:
        NoActiveScreenView(viewModel: viewModel)
      }
      RestoreOverlay(viewModel: viewModel)
    }
  }

  private var closeButtonToolbarItem: some ToolbarContent {
    ToolbarItem(placement: .navigationBarTrailing) {
      Button {
        if let onClose = navigationOptions.onClose { onClose() } else { dismiss() }
      } label: {
        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
      }
      .accessibilityLabel(viewModel.strings.string("customer_center_close"))
      .accessibilityIdentifier("customer_center.close")
    }
  }

  private var theme: CustomerCenterTheme {
    CustomerCenterTheme(appearance: viewModel.configuration.appearance, colorScheme: colorScheme)
  }

  private var themeAccent: Color? {
    guard let pair = viewModel.configuration.appearance.accent else { return nil }
    let hex = colorScheme == .dark ? pair.dark : pair.light
    return UIColor(hex: hex).map(Color.init)
  }
}
