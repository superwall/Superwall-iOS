//
//  DevServerLocatorURLSessionTests.swift
//  SuperwallKitTests
//

import Foundation
import Testing
@testable import SuperwallKit

/// Answers requests to one made-up host, so registering it globally leaves every
/// other request in the suite alone.
private final class StubURLProtocol: URLProtocol {
  static let host = "devserver-loader-stub.invalid"
  static let body = Data(#"{"surfaces":[]}"#.utf8)
  static let registered: Void = {
    URLProtocol.registerClass(StubURLProtocol.self)
  }()

  override class func canInit(with request: URLRequest) -> Bool {
    return request.url?.host == host
  }

  override class func canonicalRequest(for request: URLRequest) -> URLRequest {
    return request
  }

  override func startLoading() {
    guard let url = request.url else {
      return
    }
    switch url.path {
    case "/ok":
      respond(url: url, status: 200, body: Self.body)
    case "/missing":
      respond(url: url, status: 404, body: Data("not found".utf8))
    case "/empty":
      respond(url: url, status: 200, body: nil)
    default:
      client?.urlProtocol(self, didFailWithError: URLError(.cannotConnectToHost))
    }
  }

  override func stopLoading() {}

  private func respond(url: URL, status: Int, body: Data?) {
    let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    if let body = body {
      client?.urlProtocol(self, didLoad: body)
    }
    client?.urlProtocolDidFinishLoading(self)
  }
}

struct DevServerLocatorURLSessionTests {
  init() {
    StubURLProtocol.registered
  }

  private func load(_ path: String) async throws -> (Data, URLResponse?) {
    let url = URL(string: "http://\(StubURLProtocol.host)\(path)")!
    return try await DevServerLocator.loadWithURLSession(URLRequest(url: url))
  }

  @Test func success_returnsBodyAndResponse() async throws {
    let (data, response) = try await load("/ok")

    #expect(data == StubURLProtocol.body)
    #expect((response as? HTTPURLResponse)?.statusCode == 200)
  }

  /// The locator reads the status itself, so an error status must come back as a
  /// response rather than a thrown error.
  @Test func errorStatus_returnsResponseWithoutThrowing() async throws {
    let (data, response) = try await load("/missing")

    #expect(data == Data("not found".utf8))
    #expect((response as? HTTPURLResponse)?.statusCode == 404)
  }

  @Test func emptyBody_returnsEmptyData() async throws {
    let (data, response) = try await load("/empty")

    #expect(data.isEmpty)
    #expect((response as? HTTPURLResponse)?.statusCode == 200)
  }

  @Test func connectionFailure_throwsTheURLError() async {
    await #expect(throws: URLError.self) {
      _ = try await load("/unreachable")
    }
  }
}
