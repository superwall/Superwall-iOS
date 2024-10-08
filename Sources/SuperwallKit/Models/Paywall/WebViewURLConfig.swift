//
//  File.swift
//  
//
//  Created by Yusuf Tör on 11/07/2024.
//

import Foundation

struct WebViewURLConfig: Codable {
  let endpoints: [WebViewEndpoint]
  let maxAttempts: Int
}

struct WebViewEndpoint: Codable, Equatable {
  var url: URL
  let timeout: TimeInterval
  var percentage: Double

  enum CodingKeys: String, CodingKey {
    case url
    case timeoutMs
    case percentage
  }

  init(
    url: URL,
    timeout: TimeInterval,
    percentage: Double
  ) {
    self.url = url
    self.timeout = timeout
    self.percentage = percentage
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.url = try container.decode(URL.self, forKey: .url)
    self.timeout = try container.decode(Milliseconds.self, forKey: .timeoutMs) * 1000
    self.percentage = try container.decode(Double.self, forKey: .percentage)
  }

  func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(url, forKey: .url)
    try container.encode(timeout / 1000, forKey: .timeoutMs)
    try container.encode(percentage, forKey: .percentage)
  }
}

// MARK: - Stubbable
extension WebViewEndpoint: Stubbable {
  static func stub() -> WebViewEndpoint {
    return WebViewEndpoint(
      // swiftlint:disable:next force_unwrapping
      url: URL(string: "https://google.com")!,
      timeout: 15,
      percentage: 100
    )
  }
}
