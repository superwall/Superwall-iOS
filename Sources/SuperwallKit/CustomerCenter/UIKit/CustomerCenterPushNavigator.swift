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
    let colorScheme: ColorScheme =
      presenter?.traitCollection.userInterfaceStyle == .dark ? .dark : .light
    let theme = CustomerCenterTheme(
      appearance: viewModel.configuration.appearance,
      colorScheme: colorScheme
    )
    let hosted = destination
      .environment(\.customerCenterStrings, viewModel.strings)
      .environment(\.customerCenterTheme, theme)
      .environment(\.customerCenterNavigator, self)
      .environment(\.customerCenterSurfaceDepth, depth)
      .customerCenterSheets(viewModel: viewModel)
      .tint(theme.accent)

    let controller = CustomerCenterPushedHostingController(rootView: hosted)
    controller.onRemovedFromParent = { [weak self] in
      // Back to whatever is underneath. Depth drives which surface is allowed to present sheets,
      // so it has to come down again or the screen the user returns to stays mute.
      self?.viewModel.pushDepth = max(0, depth - 1)
    }
    viewModel.pushDepth = depth
    navigationController.pushViewController(controller, animated: true)
  }
}

/// A hosting controller that reports being popped, so the navigator can restore the depth.
@available(iOS 15.0, *)
private final class CustomerCenterPushedHostingController<Content: View>: UIHostingController<Content> {
  var onRemovedFromParent: (() -> Void)?

  override func didMove(toParent parent: UIViewController?) {
    super.didMove(toParent: parent)
    if parent == nil {
      onRemovedFromParent?()
    }
  }
}
