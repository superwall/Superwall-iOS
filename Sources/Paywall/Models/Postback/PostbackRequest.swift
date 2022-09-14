//
//  PostbackRequest.swift
//  Paywall
//
//  Created by Yusuf Tör on 02/03/2022.
//

import Foundation

struct PostBackResponse: Codable {
  var status: String
}

struct PostbackRequest: Codable {
  struct PostbackProductIdentifier: Codable {
    var identifier: String
    var platform: String

    var isiOS: Bool {
      return platform.lowercased() == "ios"
    }
  }

  var products: [PostbackProductIdentifier]
  var delay: Int?
  var postbackDelay: Double {
    if let delay = delay {
      return Double(delay) / 1000
    } else {
      return Double.random(in: 2.0 ..< 10.0)
    }
  }
  var productsToPostBack: [PostbackProductIdentifier] {
    return products.filter { $0.isiOS }
  }
}

extension PostbackRequest: Stubbable {
  static func stub() -> PostbackRequest {
    return PostbackRequest(
      products: [
        PostbackProductIdentifier(
          identifier: "123",
          platform: "ios"
        )
      ]
    )
  }
}
