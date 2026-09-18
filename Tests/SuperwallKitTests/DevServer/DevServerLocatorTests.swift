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

  /// Holds a request for one origin until the test releases it, so two
  /// lookups can be interleaved.
  private actor GatedProbe {
    private let serving: Set<String>
    private let gatedOrigin: String
    private var gate: [CheckedContinuation<Void, Never>] = []
    private var arrival: CheckedContinuation<Void, Never>?
    private var hasArrived = false
    private var isOpen = false

    init(serving: Set<String>, gating gatedOrigin: String) {
      self.serving = serving
      self.gatedOrigin = gatedOrigin
    }

    /// Returns once a request for the gated origin is waiting.
    func waitUntilGated() async {
      if hasArrived {
        return
      }
      await withCheckedContinuation { arrival = $0 }
    }

    func release() {
      isOpen = true
      for continuation in gate {
        continuation.resume()
      }
      gate = []
    }

    func load(_ request: URLRequest) async -> (Data, URLResponse?) {
      guard let url = request.url else {
        return (Data(), nil)
      }
      let origin = "\(url.scheme ?? "")://\(url.host ?? ""):\(url.port ?? 0)"
      if origin == gatedOrigin,
        !isOpen {
        hasArrived = true
        arrival?.resume()
        arrival = nil
        await withCheckedContinuation { gate.append($0) }
      }
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

  private func locator(_ probe: GatedProbe) -> DevServerLocator {
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

  @Test("A lookup still in flight for the old address can't refill the cache")
  func locate_staleLookupDoesNotOverwriteTheNewAddress() async throws {
    let old = try url("http://192.168.1.10:6100")
    let new = try url("http://192.168.1.20:6100")
    let probe = GatedProbe(
      serving: [old.absoluteString, new.absoluteString],
      gating: old.absoluteString
    )
    let locator = locator(probe)

    let stale = Task { await locator.locate(devServerURL: old) }
    await probe.waitUntilGated()

    // devServer is pointed at the new address while the old probe is waiting.
    let current = await locator.locate(devServerURL: new)
    #expect(current?.base == new)

    await probe.release()
    let staleResult = await stale.value
    #expect(staleResult == nil)

    let afterStaleFinished = await locator.locate(devServerURL: new)
    #expect(afterStaleFinished?.base == new)
  }

  @Test("A pin landing mid-lookup wins over the walk already in flight")
  func locate_pinDuringLookupWinsOverTheWalkInFlight() async throws {
    let configured = try url("http://192.168.1.10:6100")
    let pinned = try url("http://192.168.1.30:6100")
    let probe = GatedProbe(
      serving: [configured.absoluteString, pinned.absoluteString],
      gating: configured.absoluteString
    )
    let locator = locator(probe)

    let inFlight = Task { await locator.locate(devServerURL: configured) }
    await probe.waitUntilGated()

    // A superwall_dev link lands while that walk is still waiting.
    await locator.pin(base: pinned)
    let afterPin = await locator.locate(devServerURL: configured)
    #expect(afterPin?.base == pinned)

    await probe.release()
    let inFlightResult = await inFlight.value
    #expect(inFlightResult == nil)

    let afterWalkFinished = await locator.locate(devServerURL: configured)
    #expect(afterWalkFinished?.base == pinned)
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
