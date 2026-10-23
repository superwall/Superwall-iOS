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
  var hasRequestStartedCallback = false
  var configResponse: Config?

  override func request<Kind, Response>(
    _ endpoint: Endpoint<Kind, Response>,
    data: Kind.RequestData,
    onRequestStarted: (() -> Void)? = nil,
    isRetryingCallback: ((Int) -> Void)? = nil
  ) async throws -> Response where Kind : EndpointKind, Response : Decodable {
    didRequest = true
    hasRequestStartedCallback = onRequestStarted != nil
    if let response = configResponse as? Response {
      return response
    }
    return try await super.request(
      endpoint,
      data: data,
      onRequestStarted: onRequestStarted,
      isRetryingCallback: isRetryingCallback
    )
  }
}
