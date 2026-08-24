//
//  DebugPickerLogic.swift
//  SuperwallKit
//
//  Builds the debugger's paywall list: the surfaces a running
//  `superwall dev` server serves, then the paywalls the app has published.
//

import Foundation

enum DebugPickerLogic {
  enum Kind: Equatable {
    case local(index: Int)
    case published(index: Int)
  }

  struct Row: Equatable {
    let title: String
    let kind: Kind
    let isSelected: Bool
  }

  struct Section: Equatable {
    let title: String
    let rows: [Row]
  }

  static let localTitle = "Local · superwall dev"
  static let publishedTitle = "Published"

  static func sections(
    localSurfaceIds: [String],
    publishedNames: [String],
    selectedLocalId: String?,
    selectedPublishedIndex: Int?,
    query: String = ""
  ) -> [Section] {
    let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    func matches(_ title: String) -> Bool {
      return needle.isEmpty || title.lowercased().contains(needle)
    }

    let local = localSurfaceIds.enumerated()
      .filter { matches($0.element) }
      .map { index, id in
        Row(title: id, kind: .local(index: index), isSelected: id == selectedLocalId)
      }
    let published = publishedNames.enumerated()
      .filter { matches($0.element) }
      .map { index, name in
        Row(
          title: name,
          kind: .published(index: index),
          isSelected: index == selectedPublishedIndex && selectedLocalId == nil
        )
      }

    return [
      Section(title: localTitle, rows: local),
      Section(title: publishedTitle, rows: published)
    ].filter { !$0.rows.isEmpty }
  }
}
