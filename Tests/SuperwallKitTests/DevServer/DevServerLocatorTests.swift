//
//  DevServerLocatorTests.swift
//  SuperwallKitTests
//

import Foundation
import Testing
@testable import SuperwallKit

@Suite(.serialized)
struct DevServerLocatorTests {
  private static let manifest = Data("""
  {"surfaces":[{"kind":"paywall","id":"pro","url":"/preview/paywall/pro"}]}
  """.utf8)

  /// Answers the manifest probe for the origins it is told are serving, and
  /// records everything it was asked for.
  private actor Probe {
    private(set) var requestedURLs: [URL] = []
    private let serving: Set<String>

    init(serving: Set<String>) {
      self.serving = serving
    }

    func load(_ request: URLRequest) -> (Data, URLResponse?) {
      guard let url = request.url else {
        return (Data(), nil)
      }
      requestedURLs.append(url)
      let origin = "\(url.scheme ?? "")://\(url.host ?? ""):\(url.port ?? 0)"
      let isServing = serving.contains(origin)
      let response = HTTPURLResponse(
        url: url,
        statusCode: isServing ? 200 : 404,
        httpVersion: nil,
        headerFields: nil
      )
      return (isServing ? DevServerLocatorTests.manifest : Data(), response)
    }
  }

  private func locator(_ probe: Probe) -> DevServerLocator {
    return DevServerLocator { request in
      await probe.load(request)
    }
  }

  private func url(_ string: String) throws -> URL {
    return try #require(URL(string: string))
  }

  @Test("Reuses the server it just found for the same address")
  func locate_cachesHitForSameAddress() async throws {
    let base = try url("http://192.168.1.10:6100")
    let probe = Probe(serving: [base.absoluteString])
    let locator = locator(probe)

    let first = await locator.locate(devServerURL: base)
    #expect(first?.base == base)

    let second = await locator.locate(devServerURL: base)
    #expect(second?.base == base)

    let requestedURLs = await probe.requestedURLs
    #expect(requestedURLs.count == 1)
  }

  @Test("Pointing devServer somewhere else drops the cached server")
  func locate_discardsHitWhenAddressChanges() async throws {
    let old = try url("http://192.168.1.10:6100")
    let new = try url("http://192.168.1.20:6100")
    let probe = Probe(serving: [old.absoluteString, new.absoluteString])
    let locator = locator(probe)

    let first = await locator.locate(devServerURL: old)
    #expect(first?.base == old)

    let second = await locator.locate(devServerURL: new)
    #expect(second?.base == new)
  }

  @Test("A miss at one address doesn't suppress the lookup at another")
  func locate_discardsMissWhenAddressChanges() async throws {
    let missing = try url("http://192.168.1.10:6100")
    let running = try url("http://192.168.1.20:6100")
    let probe = Probe(serving: [running.absoluteString])
    let locator = locator(probe)

    let first = await locator.locate(devServerURL: missing)
    #expect(first == nil)

    let second = await locator.locate(devServerURL: running)
    #expect(second?.base == running)
  }

  @Test("A deep link's pin wins over the address devServer names")
  func locate_pinnedBaseWinsOverConfiguredAddress() async throws {
    let configured = try url("http://192.168.1.10:6100")
    let pinned = try url("http://192.168.1.30:6100")
    let probe = Probe(serving: [pinned.absoluteString])
    let locator = locator(probe)

    await locator.pin(base: pinned)

    let located = await locator.locate(devServerURL: configured)
    #expect(located?.base == pinned)
  }

  @Test("Pointing devServer somewhere else drops a deep link's pin")
  func locate_discardsPinWhenAddressChanges() async throws {
    let configured = try url("http://192.168.1.10:6100")
    let pinned = try url("http://192.168.1.30:6100")
    let new = try url("http://192.168.1.20:6100")
    let probe = Probe(serving: [pinned.absoluteString, new.absoluteString])
    let locator = locator(probe)

    _ = await locator.locate(devServerURL: configured)
    await locator.pin(base: pinned)
    let beforeChange = await locator.locate(devServerURL: configured)
    #expect(beforeChange?.base == pinned)

    let located = await locator.locate(devServerURL: new)
    #expect(located?.base == new)
  }

  @Test("Forgetting drops the cached server and the pin")
  func forget_clearsCacheAndPin() async throws {
    let configured = try url("http://192.168.1.10:6100")
    let pinned = try url("http://192.168.1.30:6100")
    let probe = Probe(serving: [pinned.absoluteString])
    let locator = locator(probe)

    await locator.pin(base: pinned)
    let beforeForgetting = await locator.locate(devServerURL: configured)
    #expect(beforeForgetting?.base == pinned)

    await locator.forget()
    let located = await locator.locate(devServerURL: configured)
    #expect(located == nil)
  }
}
