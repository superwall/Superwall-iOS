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

  override func request<Kind, Response>(
    _ endpoint: Endpoint<Kind, Response>,
    data: Kind.RequestData,
    isRetryingCallback: ((Int) -> Void)? = nil
  ) async throws -> Response where Kind : EndpointKind, Response : Decodable {
    didRequest = true
    return try await super.request(endpoint, data: data, isRetryingCallback: isRetryingCallback)
  }
}
