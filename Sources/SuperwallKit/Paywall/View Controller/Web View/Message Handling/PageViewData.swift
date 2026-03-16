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

  /// How the user navigated to the page. Possible values:
  /// `"entry"`, `"forward"`, `"back"`, `"auto_transition"`.
  public let navigationType: String

  /// Time spent on the previous page in milliseconds, if any.
  public let timeOnPreviousPageMs: Int?

  private enum CodingKeys: String, CodingKey {
    case pageNodeId
    case flowPosition
    case pageName
    case navigationNodeId
    case previousPageNodeId
    case previousFlowPosition
    case navigationType = "type"
    case timeOnPreviousPageMs
  }
}
