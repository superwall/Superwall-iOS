//
//  File.swift
//  
//
//  Created by Yusuf Tör on 19/06/2023.
//

import Foundation

struct LocalNotification: Decodable {
  let type: LocalNotificationType
  let title: String
  let subtitle: String?
  let body: String
  let delay: Milliseconds
}

enum LocalNotificationType: Decodable {
  case freeTrial
//
//  enum CodingKeys: String {
//    case freeTrial
//  }
//
//  public init(from decoder: Decoder) throws {
//    let container = try decoder.singleValueContainer()
//    let rawValue = try container.decode(String.self)
//    let notificationType = CodingKeys(rawValue: rawValue) ?? .freeTrial
//    switch notificationType {
//    case .freeTrial:
//      self = .freeTrial
//    }
//  }
}
