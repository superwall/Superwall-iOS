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
  /// Supplied when the host owns the navigation, so drill-downs push onto their stack.
  private let navigator: CustomerCenterNavigating?
  @Environment(\.dismiss) private var dismiss
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
    navigator = nil
  }

  private static func makeConfiguredViewModel(
    configuration: CustomerCenterConfiguration?,
    usesExistingNavigation: Bool
  ) -> CustomerCenterViewModel {
    let model = CustomerCenterManager.makeViewModel(configuration: configuration)
    model.presentationMode = usesExistingNavigation ? "embedded" : "sheet"
    return model
  }

  init(
    viewModel: CustomerCenterViewModel,
    navigationOptions: CustomerCenterNavigationOptions,
    navigator: CustomerCenterNavigating? = nil
  ) {
    _viewModel = StateObject(wrappedValue: viewModel)
    self.navigationOptions = navigationOptions
    self.navigator = navigator
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
    .environment(\.customerCenterNavigator, navigator)
    .task {
      viewModel.callbacks = Self.merged(viewModel.callbacks, callbacksBox.callbacks)
      await viewModel.load()
    }
    // Part of the visibility count that determines when the Customer Center has genuinely
    // closed — see `CustomerCenterViewModel.surfaceDidAppear()`.
    .onAppear { viewModel.surfaceDidAppear() }
    .onDisappear { viewModel.surfaceDidDisappear() }
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
  // toggled here at the plain `@ViewBuilder` level instead, which iOS 15 supports. Branching on
  // the flag is safe even though branch flips tear down modifiers: it comes from
  // `navigationOptions`, fixed for the view's lifetime, so it can't flip mid-update.
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
      // `.identity` so the content doesn't animate: it belongs to the same transaction as the
      // cover's removal, and without this it would take SwiftUI's default opacity transition and
      // fade in while the cover fades out. The content should simply be there, revealed.
      loadedContent.transition(.identity)
      RestoreOverlay(viewModel: viewModel)
    }
    // The spinner covers the screen rather than standing in for it, so the content isn't built
    // and swapped underneath the user — it's simply revealed as the cover fades. The animation
    // lives here, on the view that owns the condition, because that's what supplies the
    // transaction the cover's removal transition runs in.
    .overlay(loadingCover)
    .animation(loadingCoverAnimation, value: viewModel.state)
  }

  @ViewBuilder
  private var loadedContent: some View {
    switch viewModel.state {
    case .loading:
      // Nothing yet — whether this becomes the management or the no-purchases screen isn't known
      // until the load finishes, and guessing would show the wrong one for a frame.
      Color.clear
    case .management:
      ManagementScreenView(viewModel: viewModel)
    case .noPurchases:
      NoPurchasesScreenView(viewModel: viewModel)
    }
  }

  /// The cover's fade. Applied to the container rather than the cover itself: a modifier on the
  /// departing view isn't what drives its removal transition.
  private var loadingCoverAnimation: Animation? {
    reduceMotion ? nil : .easeOut(duration: 0.24)
  }

  @ViewBuilder
  private var loadingCover: some View {
    if viewModel.state == .loading {
      ZStack {
        // Opaque, so nothing shows through and no touch reaches a half-built screen. Honours a
        // configured background, falling back to the grouped-list colour the screen uses.
        (theme.background ?? Color(uiColor: .systemGroupedBackground))
        ProgressView().accessibilityIdentifier("customer_center.loading")
      }
      // Edge to edge, because the `List` this becomes already runs under the navigation bar and
      // past the home indicator with the same background. Confining the cover to the safe area
      // leaves it floating in a frame of unpainted screen, and the region it covers ends up the
      // same colour either way — so there's no bar being flattened, only continuity.
      .ignoresSafeArea()
      .transition(.opacity)
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
