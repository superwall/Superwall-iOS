//
//  CustomerCenterPushNavigator.swift
//
//
//  Created by Jordan Morgan on 28/08/2026.
//

import SwiftUI
import UIKit

/// Pushes the Customer Center's drill-downs onto the host's own navigation controller.
///
/// Used only by ``CustomerCenterPresentationStyle/pushed``, where there's no SwiftUI navigation
/// ancestor for `NavigationLink` to use. Each destination becomes its own hosting controller, so
/// the host's navigation bar drives it — their back button, their title treatment, their
/// appearance — and nothing of theirs is modified.
@available(iOS 15.0, *)
@MainActor
final class CustomerCenterPushNavigator: CustomerCenterNavigating {
  weak var presenter: UIViewController?
  private let viewModel: CustomerCenterViewModel

  init(viewModel: CustomerCenterViewModel) {
    self.viewModel = viewModel
  }

  func push<Destination: View>(_ destination: Destination) {
    guard let navigationController = presenter?.navigationController else { return }

    // A pushed destination is a fresh SwiftUI root: nothing from the presenting hierarchy's
    // environment reaches it, so the Customer Center's own values have to be reapplied.
    let depth = viewModel.pushDepth + 1
    // The theme is resolved inside the destination rather than captured here, so it follows the
    // colour scheme. Reading `traitCollection` at push time would freeze a pushed screen in
    // whichever appearance was active when it opened, while the root kept tracking the change.
    let hosted = CustomerCenterThemedContainer(
      appearance: viewModel.configuration.appearance,
      content: destination.customerCenterSheets(viewModel: viewModel, surfaceDepth: depth)
    )
      .environment(\.customerCenterStrings, viewModel.strings)
      .environment(\.customerCenterNavigator, self)

    let controller = CustomerCenterPushedHostingController(rootView: hosted)
    controller.onRemovedFromParent = { [weak self] in
      // Back to whatever is underneath. `min` rather than a plain assignment because popping
      // several screens at once removes them all and UIKit doesn't document the order it calls
      // `didMove(toParent:)` in: taking the lowest reported depth is the same answer whichever
      // way round they arrive, where assigning leaves the depth stranded above the surface the
      // user is actually on — and that surface then can't present anything for the rest of the
      // presentation.
      guard let self else { return }
      self.viewModel.pushDepth = min(self.viewModel.pushDepth, depth - 1)
    }
    controller.onCoveredWhileStillInStack = { [weak self] in
      self?.viewModel.cancelPendingDismissal()
    }
    viewModel.pushDepth = depth
    navigationController.pushViewController(controller, animated: true)
  }
}

/// Applies the Customer Center's theme to a pushed screen, recomputing it whenever the colour
/// scheme changes. A pushed destination is its own SwiftUI root, so it inherits nothing from the
/// screen that pushed it.
@available(iOS 15.0, *)
private struct CustomerCenterThemedContainer<Content: View>: View {
  let appearance: CustomerCenterConfiguration.Appearance
  let content: Content
  @Environment(\.colorScheme) private var colorScheme

  private var theme: CustomerCenterTheme {
    CustomerCenterTheme(appearance: appearance, colorScheme: colorScheme)
  }

  var body: some View {
    content
      .environment(\.customerCenterTheme, theme)
      .tint(theme.accent)
  }
}

/// A hosting controller that reports being popped, so the navigator can restore the depth, and
/// vetoes the dismissal debounce when it is merely covered.
@available(iOS 15.0, *)
private final class CustomerCenterPushedHostingController<Content: View>: UIHostingController<Content> {
  var onRemovedFromParent: (() -> Void)?
  var onCoveredWhileStillInStack: (() -> Void)?
  private var hasReportedRemoval = false

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    if isMovingFromParent || isBeingDismissed {
      reportRemoval()
      return
    }
    // Merely covered — the host pushed its own screen on top, presented something, or the user
    // switched tabs. `super` has just forwarded the disappearance into SwiftUI, whose
    // `onDisappear` dropped the visible-surface count to zero and armed the dismissal debounce.
    // Left to fire it would deliver `customerCenterDidDismiss()` and latch, silencing the real
    // teardown later. Same veto the root controller performs, one level down.
    onCoveredWhileStillInStack?()
  }

  override func didMove(toParent parent: UIViewController?) {
    super.didMove(toParent: parent)
    // Not redundant with the above: a controller that was already covered has disappeared once
    // already, so being popped from under the covering screen produces no second disappearance.
    if parent == nil {
      reportRemoval()
    }
  }

  /// Latched, because an ordinary pop is both a disappearance and a removal from the container.
  private func reportRemoval() {
    guard !hasReportedRemoval else { return }
    hasReportedRemoval = true
    onRemovedFromParent?()
  }
}
