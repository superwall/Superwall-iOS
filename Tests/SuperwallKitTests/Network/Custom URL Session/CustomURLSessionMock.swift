//
//  File.swift
//  
//
//  Created by Yusuf Tör on 23/06/2022.
//

import Foundation
@testable import SuperwallKit

final class CustomURLSessionMock: CustomURLSession {
  var didRequest = false

  override func request<Response>(
    _ endpoint: Endpoint<Response>
  ) async throws -> Response where Response: Decodable {
    didRequest = true
    return try await super.request(endpoint)
  }
}
