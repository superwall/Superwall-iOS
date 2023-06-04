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

  @discardableResult
  override func request<Response>(
    _ endpoint: Endpoint<Response>,
    isRetryingCallback: (() -> Void)? = nil
  ) async throws -> Response {
    didRequest = true
    return try await super.request(endpoint)
  }
}
