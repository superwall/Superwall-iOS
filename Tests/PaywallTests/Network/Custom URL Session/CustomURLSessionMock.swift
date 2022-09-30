//
//  File.swift
//  
//
//  Created by Yusuf Tör on 23/06/2022.
//

import Foundation
@testable import Paywall

final class CustomURLSessionMock: CustomURLSession {
  var didRequest = false

  override func request<Response>(
    _ endpoint: Endpoint<Response>,
    isForDebugging: Bool = false
  ) async throws -> Response where Response : Decodable {
    didRequest = true
    return try await super.request(endpoint, isForDebugging: isForDebugging)
  }
}
