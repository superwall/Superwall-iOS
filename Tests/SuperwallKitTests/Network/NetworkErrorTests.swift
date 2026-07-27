//
//  NetworkErrorTests.swift
//  SuperwallKitTests
//
//  Created by Yusuf Tör on 27/07/2026.
//

import Testing
@testable import SuperwallKit

struct NetworkErrorTests {
  @Test("Successful responses produce no error", arguments: [200, 201, 202, 204, 299])
  func make_successfulResponses(statusCode: Int) {
    #expect(NetworkError.make(fromStatusCode: statusCode) == nil)
  }

  @Test("401 keeps its dedicated error")
  func make_unauthorized() {
    #expect(NetworkError.make(fromStatusCode: 401) == .notAuthenticated)
  }

  @Test("404 keeps its dedicated error")
  func make_notFound() {
    #expect(NetworkError.make(fromStatusCode: 404) == .notFound)
  }

  @Test(
    "Other client errors surface the status code rather than a decoding failure",
    arguments: [400, 403, 405, 410, 422, 429]
  )
  func make_otherClientErrors(statusCode: Int) {
    #expect(NetworkError.make(fromStatusCode: statusCode) == .http(statusCode: statusCode))
  }

  @Test(
    "Server errors surface the status code rather than a decoding failure",
    arguments: [500, 502, 503, 504]
  )
  func make_serverErrors(statusCode: Int) {
    #expect(NetworkError.make(fromStatusCode: statusCode) == .http(statusCode: statusCode))
  }

  @Test("Redirects that reach the caller are treated as errors")
  func make_redirect() {
    #expect(NetworkError.make(fromStatusCode: 302) == .http(statusCode: 302))
  }

  @Test("The status code is included in the error description")
  func errorDescription_includesStatusCode() {
    let error = NetworkError.http(statusCode: 403)
    #expect(error.errorDescription?.contains("403") == true)
  }

  @Test("Log messages are preserved for the dedicated cases")
  func logMessage() {
    #expect(NetworkError.notAuthenticated.logMessage == "Unable to Authenticate")
    #expect(NetworkError.notFound.logMessage == "Not Found")
    #expect(NetworkError.http(statusCode: 403).logMessage == "Request Failed")
  }
}
