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
/// screen pushed through UIKit: it carries its own sheet modifiers and claims them while it's on
/// top.
///
/// A sheet presents from the screen whose modifier asked for it, and UIKit takes the screens under
/// a pushed one out of the window. With only the root's modifiers, every sheet a pushed screen
/// asked for — the cancellation survey, change plan, the web management page — waited, silently,
/// for the user to go back to the root, and then appeared there with no animation.
///
/// The claim is made on appear and released only when the screen leaves the stack: UIKit reports it
/// popped or dismissed, or SwiftUI takes it down. Being covered — by a deeper screen, a tab switch,
/// anything the host presents — releases nothing, and neither does a swipe back the user cancels.
/// `onDisappear` fires for a cover too, which is why it can't be the release.
@available(iOS 15.0, *)
private struct CustomerCenterLinkedScreen: ViewModifier {
  let viewModel: CustomerCenterViewModel
  let surfaceDepth: Int
  /// This screen's claim, stable for its lifetime: claiming again on each appearance changes
  /// nothing, and a release can only take back this screen's own claim.
  @State private var claim = UUID()

  func body(content: Content) -> some View {
    content
      .customerCenterSheets(viewModel: viewModel, surfaceDepth: surfaceDepth)
      .environment(\.customerCenterSurfaceDepth, surfaceDepth)
      .onAppear { viewModel.claimPushedSurface(claim, depth: surfaceDepth) }
      .background(
        CustomerCenterLifecycleProbe(
          // The same veto the UIKit navigator's screens apply: covered isn't closed.
          onCovered: { [viewModel] in viewModel.suppressDismissalUntilNextAppearance() },
          onRemoved: { [viewModel, claim] in
            viewModel.releasePushedSurface(claim)
            viewModel.surfaceWasRemoved()
          },
          // Also covers a screen popped while something covered it, which doesn't disappear a
          // second time. `NavigationView` doesn't promise to take a popped screen down promptly,
          // which is why this isn't the only release.
          onDismantled: { [viewModel, claim] in viewModel.releasePushedSurface(claim) }
        )
      )
  }
}

/// The Customer Center's own screens pushed above its root, each under a claim of its own.
///
/// Claims rather than a single depth, so the order screens report in can't matter. SwiftUI doesn't
/// promise the incoming screen appears before the outgoing one goes, and UIKit doesn't say which
/// of several screens popped together reports first. With one number, whichever came last won:
/// a screen replaced by another at the same depth — the detail column of a split view — could hand
/// the depth back to the root while the new screen was on top, and the root, out of the window,
/// would then own every sheet.
struct PushedSurfaces: Equatable {
  struct Claim: Equatable {
    let id: UUID
    let depth: Int
  }

  /// Shallowest first. A claim replaces everything at its depth or deeper, so this stays in order.
  private(set) var claims: [Claim] = []

  /// The depth of the screen on top; `0` when it's the root.
  var depth: Int { claims.last?.depth ?? 0 }

  /// A screen at `depth` is on top, so any screen recorded at that depth or deeper has been
  /// replaced, whether or not its own release has arrived yet.
  mutating func claim(_ id: UUID, depth: Int) {
    claims.removeAll { $0.id == id || $0.depth >= depth }
    claims.append(Claim(id: id, depth: depth))
  }

  /// Removes `id`'s claim, if it still holds one. A claim a later screen replaced is already gone.
  mutating func release(_ id: UUID) {
    claims.removeAll { $0.id == id }
  }
}
