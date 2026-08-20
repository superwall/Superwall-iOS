//
//  CustomerCenterManager.swift
//
//
//  Created by Claude on 20/08/2026.
//

import Foundation

/// Builds the dependencies and view model backing ``CustomerCenterView``.
///
/// This file currently holds just the static factory `CustomerCenterView` needs. It is expanded
/// with the full public presentation API in a later commit.
@available(iOS 15.0, *)
@MainActor
enum CustomerCenterManager {
  static func makeViewModel(configuration: CustomerCenterConfiguration?) -> CustomerCenterViewModel {
    let container = Superwall.shared.dependencyContainer
    let resolved = configuration ?? container.configManager.options.customerCenter
    let dependencies = CustomerCenterDependencies.live(container: container, configuration: resolved)
    return CustomerCenterViewModel(
      configuration: resolved,
      dependencies: dependencies,
      strings: .bundled()
    )
  }
}
