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
private struct CustomerCenterSurfaceDepthKey: EnvironmentKey {
  static let defaultValue = 0
}

@available(iOS 15.0, *)
extension EnvironmentValues {
  var customerCenterNavigator: CustomerCenterNavigating? {
    get { self[CustomerCenterNavigatorKey.self] }
    set { self[CustomerCenterNavigatorKey.self] = newValue }
  }

  /// How deep the screen being built sits in the Customer Center's own `NavigationLink` stack;
  /// `0` for the root. A drill-down reads it to know the depth of the screen it pushes.
  var customerCenterSurfaceDepth: Int {
    get { self[CustomerCenterSurfaceDepthKey.self] }
    set { self[CustomerCenterSurfaceDepthKey.self] = newValue }
  }
}

/// A row that drills into another Customer Center screen, by whichever mechanism the surrounding
/// navigation supports.
@available(iOS 15.0, *)
struct CustomerCenterDrillDown<Label: View, Destination: View>: View {
  let viewModel: CustomerCenterViewModel
  @Environment(\.customerCenterNavigator) private var navigator
  @Environment(\.customerCenterSurfaceDepth) private var surfaceDepth
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
      NavigationLink(
        destination: destination().modifier(
          CustomerCenterLinkedScreen(viewModel: viewModel, surfaceDepth: surfaceDepth + 1)
        ),
        label: label
      )
    }
  }
}

/// A screen `NavigationLink` pushed, doing for itself what `CustomerCenterPushNavigator` does for a
/// screen pushed through UIKit: it carries its own sheet modifiers and takes them over while it's
/// on top.
///
/// A sheet presents from the screen whose modifier asked for it, and UIKit takes the screens under
/// a pushed one out of the window. With only the root's modifiers, every sheet a pushed screen
/// asked for — the cancellation survey, change plan, the web management page — waited, silently,
/// for the user to go back to the root, and then appeared there with no animation.
///
/// The depth is claimed on appear and handed back on disappear. A sheet covering this screen
/// fires neither, so the depth only moves when the screen is pushed or popped.
@available(iOS 15.0, *)
private struct CustomerCenterLinkedScreen: ViewModifier {
  let viewModel: CustomerCenterViewModel
  let surfaceDepth: Int

  func body(content: Content) -> some View {
    content
      .customerCenterSheets(viewModel: viewModel, surfaceDepth: surfaceDepth)
      .environment(\.customerCenterSurfaceDepth, surfaceDepth)
      .onAppear { viewModel.pushDepth = surfaceDepth }
      // `min` rather than assigning, as the UIKit navigator does: when several screens go at once,
      // whichever reports last mustn't leave the depth above the screen the user is actually on.
      .onDisappear { viewModel.pushDepth = min(viewModel.pushDepth, surfaceDepth - 1) }
  }
}
