//
//  EventData.swift
//  Paywall
//
//  Created by Yusuf Tör on 02/03/2022.
//

import Foundation

struct EventData: Codable {
  var id = UUID().uuidString
  var name: String
  var parameters: JSON
  var createdAt: String
  var jsonData: JSON {
    return [
      "event_id": JSON(id),
      "event_name": JSON(name),
      "parameters": parameters,
      "created_at": JSON(createdAt)
    ]
  }
}
