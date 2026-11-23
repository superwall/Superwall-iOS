//
//  GameControllerEvent.swift
//  Superwall
//
//  Created by Yusuf Tör on 28/02/2022.
//

#if canImport(WebKit)
import Foundation

struct GameControllerEvent: Codable {
  var eventName = "game_controller_input"
  var controllerElement: String
  var value: Double
  var x: Double
  var y: Double
  var directional: Bool

  var jsonString: String? {
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase

    if let data = try? encoder.encode(self) {
      return String(data: data, encoding: .utf8)
    }
    return nil
  }
}
#endif
