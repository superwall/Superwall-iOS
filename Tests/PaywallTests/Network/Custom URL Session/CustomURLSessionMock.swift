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
    isForDebugging: Bool = false,
    completion: @escaping (Result<Response, Error>) -> Void,
    attempt: Double = 1
  ) {
    didRequest = true
  }
}
