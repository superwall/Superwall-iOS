//
//  PageViewData.swift
//
//
//  Created by Yusuf Tör on 16/03/2026.
//

import Foundation

/// Contains page-specific details for a multi-page paywall page view.
public struct PageViewData: Decodable, Equatable {
  /// The unique identifier for the page node.
  public let pageNodeId: String

  /// The zero-based index of the page in the paywall flow.
  public let flowPosition: Int

  /// The display name of the page.
  public let pageName: String

  /// The unique identifier for the navigation node.
  public let navigationNodeId: String

  /// The unique identifier for the previous page node, if any.
  public let previousPageNodeId: String?

  /// The flow position of the previous page, if any.
  public let previousFlowPosition: Int?

  /// How the user navigated to the page (e.g. "entry", "forward", "back").
  public let type: String

  /// Time spent on the previous page in milliseconds, if any.
  public let timeOnPreviousPageMs: Int?
}
