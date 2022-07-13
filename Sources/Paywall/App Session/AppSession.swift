//
//  File.swift
//  
//
//  Created by Yusuf Tör on 03/05/2022.
//

import Foundation

struct AppSession: Codable, Equatable {
  /// The ID of the session.
  var id = UUID().uuidString

  /// When the app session started.
  var startAt = Date()

  /// When the app session ended.
  var endAt: Date?

  enum CodingKeys: String, CodingKey {
    case id = "app_session_id"
    case startAt = "app_session_start_ts"
    case endAt = "app_session_end_ts"
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(startAt, forKey: .startAt)
    try container.encodeIfPresent(endAt, forKey: .endAt)
  }
}

// MARK: - Stubbable
extension AppSession: Stubbable {
  static func stub() -> AppSession {
    return AppSession()
  }
}
