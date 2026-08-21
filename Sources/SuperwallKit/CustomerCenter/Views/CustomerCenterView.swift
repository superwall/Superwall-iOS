//
//  CustomerCenterView.swift
//
//
//  Created by Jordan Morgan on 20/08/2026.
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
  @Environment(\.customerCenterCallbacks) private var callbacksBox

  /// Creates a Customer Center view.
  /// - Parameters:
  ///   - configuration: Overrides ``SuperwallOptions/customerCenter``. `nil` uses the options value.
  ///   - navigationOptions: How the view integrates with navigation.
  public init(
    configuration: CustomerCenterConfiguration? = nil,
    navigationOptions: CustomerCenterNavigationOptions = .default
  ) {
    // `StateObject(wrappedValue:)` takes an `@autoclosure`, so inlining the construction call
    // directly into the argument defers it until SwiftUI installs the state object for the
    // first time. Building the model in a local `let` first would rebuild it on every
    // `CustomerCenterView.init` (i.e. on every parent body evaluation) and throw it away.
    _viewModel = StateObject(
      wrappedValue: Self.makeConfiguredViewModel(
        configuration: configuration,
        usesExistingNavigation: navigationOptions.usesExistingNavigation
      )
    )
    self.navigationOptions = navigationOptions
  }

  private static func makeConfiguredViewModel(
    configuration: CustomerCenterConfiguration?,
    usesExistingNavigation: Bool
  ) -> CustomerCenterViewModel {
    let model = CustomerCenterManager.makeViewModel(configuration: configuration)
    model.presentationMode = usesExistingNavigation ? "embedded" : "sheet"
    return model
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
    .task {
      viewModel.callbacks = Self.merged(viewModel.callbacks, callbacksBox.callbacks)
      await viewModel.load()
    }
    // `rootViewDidDisappear` skips the dismissal when a screen the Customer Center pushed
    // itself (detail / history) covers the root view in embedded mode.
    .onDisappear { viewModel.rootViewDidDisappear() }
  }

  /// Combines the view model's existing callbacks (e.g. set by the UIKit adapter) with those
  /// accumulated in the environment by `.onCustomerCenter*` modifiers, preferring the
  /// environment's non-nil closures for each field. Not `private` so it stays directly testable;
  /// it's still excluded from the SDK's public interface.
  static func merged(
    _ existing: CustomerCenterCallbacks,
    _ environment: CustomerCenterCallbacks
  ) -> CustomerCenterCallbacks {
    var result = existing
    result.shouldRestore = environment.shouldRestore ?? existing.shouldRestore
    result.didSelectAction = environment.didSelectAction ?? existing.didSelectAction
    result.didCompleteSurvey = environment.didCompleteSurvey ?? existing.didCompleteSurvey
    result.didCompleteRefund = environment.didCompleteRefund ?? existing.didCompleteRefund
    result.didDismiss = environment.didDismiss ?? existing.didDismiss
    return result
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
      case .noPurchases:
        NoPurchasesScreenView(viewModel: viewModel)
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

  private var themeAccent: Color? { theme.accent }
}
