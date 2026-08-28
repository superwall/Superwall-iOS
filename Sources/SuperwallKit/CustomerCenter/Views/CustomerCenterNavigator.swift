//
//  CustomerCenterNavigator.swift
//
//
//  Created by Jordan Morgan on 28/08/2026.
//

import SwiftUI

/// Pushes one of the Customer Center's own screens — purchase history, purchase detail.
///
/// Exists because SwiftUI's `NavigationLink` needs a SwiftUI navigation ancestor, and a
/// `UINavigationController` isn't one. When a host pushes ``CustomerCenterViewController`` onto its
/// own stack there's no such ancestor, so the drill-downs have to be pushed through UIKit instead.
/// Everywhere else — presented modally, or embedded in the host's own SwiftUI navigation — this is
/// `nil` and `NavigationLink` does the work.
@available(iOS 15.0, *)
@MainActor
protocol CustomerCenterNavigating: AnyObject {
  func push<Destination: View>(_ destination: Destination)
}

@available(iOS 15.0, *)
private struct CustomerCenterNavigatorKey: EnvironmentKey {
  static let defaultValue: CustomerCenterNavigating? = nil
}

@available(iOS 15.0, *)
extension EnvironmentValues {
  var customerCenterNavigator: CustomerCenterNavigating? {
    get { self[CustomerCenterNavigatorKey.self] }
    set { self[CustomerCenterNavigatorKey.self] = newValue }
  }
}

@available(iOS 15.0, *)
private struct CustomerCenterSurfaceDepthKey: EnvironmentKey {
  static let defaultValue = 0
}

@available(iOS 15.0, *)
extension EnvironmentValues {
  /// How many Customer Center screens have been pushed above the root through UIKit. Compared
  /// against ``CustomerCenterViewModel/pushDepth`` so that only the topmost surface presents
  /// sheets — otherwise every screen still in the stack would race to present the same one.
  var customerCenterSurfaceDepth: Int {
    get { self[CustomerCenterSurfaceDepthKey.self] }
    set { self[CustomerCenterSurfaceDepthKey.self] = newValue }
  }
}

/// A row that drills into another Customer Center screen, by whichever mechanism the surrounding
/// navigation supports.
@available(iOS 15.0, *)
struct CustomerCenterDrillDown<Label: View, Destination: View>: View {
  @Environment(\.customerCenterNavigator) private var navigator
  @ViewBuilder let destination: () -> Destination
  @ViewBuilder let label: () -> Label

  var body: some View {
    // Branching on `navigator` is safe: it's fixed for the lifetime of the hierarchy, so this
    // can't flip mid-update and tear down a modifier that was about to do something.
    if let navigator {
      Button {
        navigator.push(destination())
      } label: {
        HStack {
          label()
          Spacer()
          // `NavigationLink` draws its own chevron; this branch has to supply one, and the row
          // does push, so the chevron is telling the truth.
          Image(systemName: "chevron.forward")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
    } else {
      NavigationLink(destination: destination(), label: label)
    }
  }
}
