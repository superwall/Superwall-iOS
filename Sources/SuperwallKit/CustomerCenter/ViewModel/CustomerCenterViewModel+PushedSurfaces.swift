//
//  CustomerCenterViewModel+PushedSurfaces.swift
//
//
//  Created by Jordan Morgan on 23/09/2026.
//

import Foundation

// MARK: - Pushed screens

@available(iOS 15.0, *)
extension CustomerCenterViewModel {
  /// Records a screen the Customer Center has pushed. Claiming again under the same `id` changes
  /// nothing, so a screen can claim each time it appears.
  func claimPushedSurface(_ id: UUID, depth: Int) {
    updatePushedSurfaces { $0.claim(id, depth: depth) }
  }

  /// Forgets a pushed screen once it has left the stack. Not for a screen that is only covered:
  /// it's still in the stack, and still where its sheets belong.
  func releasePushedSurface(_ id: UUID) {
    updatePushedSurfaces { $0.release(id) }
  }

  private func updatePushedSurfaces(_ update: (inout PushedSurfaces) -> Void) {
    var surfaces = pushedSurfaces
    update(&surfaces)
    // Every assignment publishes, and screens claim on every appearance.
    guard surfaces != pushedSurfaces else { return }
    let remaining = Set(surfaces.claims.map(\.id))
    let departed = pushedSurfaces.claims.filter { !remaining.contains($0.id) }
    if let owner = sheetOwnerDepth, departed.contains(where: { $0.depth <= owner }) {
      abandonSheet()
    }
    pushedSurfaces = surfaces
  }

  /// Drops a request whose screen has left the stack, along with what making it set up. The user
  /// went back while it was still resolving, and nothing is left that could present it. Left in
  /// place, it would sit in ``sheet`` indefinitely, with a survey's pending answer still waiting.
  ///
  /// The refund's product is kept: StoreKit may already be showing that sheet, and its completion
  /// reports the outcome against it. The next refund request replaces it.
  private func abandonSheet() {
    if case .survey = sheet {
      cancelSurvey()
    } else {
      sheet = nil
    }
  }
}
