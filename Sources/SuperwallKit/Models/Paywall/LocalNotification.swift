//
//  File.swift
//  
//
//  Created by Yusuf Tör on 19/06/2023.
//

import Foundation

/// A local notification.
@objc(SWKLocalNotification)
@objcMembers
public final class LocalNotification: NSObject, Decodable {
  /// The type of the notification.
  public let type: LocalNotificationType

  /// The title text of the notification.
  public let title: String

  /// The subtitle text of the notification.
  public let subtitle: String?

  /// The body text of the notification.
  public let body: String

  /// The delay to the notification in minutes.
  public let delay: Int

  enum CodingKeys: String, CodingKey {
    case type = "notificationType"
    case title = "title"
    case subtitle = "subtitle"
    case body = "body"
    case delay = "delay"
  }

  public init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    type = try values.decode(LocalNotificationType.self, forKey: .type)
    title = try values.decode(String.self, forKey: .title)
    subtitle = try values.decodeIfPresent(String.self, forKey: .subtitle)
    body = try values.decode(String.self, forKey: .body)
    delay = try values.decode(Int.self, forKey: .delay)
  }
}

/// The type of notification.
@objc(SWKLocalNotificationType)
public enum LocalNotificationType: Int, Decodable {
  /// The notification will fire after a transaction.
  case trialStarted
}
