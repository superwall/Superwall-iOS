import Foundation
import Testing
@testable import SuperwallKit

struct DeviceIPCollectorTests {
  private let date = Date(timeIntervalSince1970: 1_789_505_000)

  private actor FetchCounter {
    var count = 0
    var shouldFail: Bool

    init(shouldFail: Bool = false) {
      self.shouldFail = shouldFail
    }

    func fetch() throws -> [String: String] {
      count += 1
      if shouldFail {
        throw URLError(.timedOut)
      }
      return [:]
    }

    func setShouldFail(_ value: Bool) {
      shouldFail = value
    }
  }

  @Test func keepsFamiliesSeparateAndRejectsStaleOrInvalidObservations() async {
    let collector = DeviceIPCollector(url: nil, now: { date })
    let timestamp = ISO8601DateFormatter.string(from: date, timeZone: TimeZone(secondsFromGMT: 0)!, formatOptions: [.withInternetDateTime, .withFractionalSeconds])
    await collector.record(["ipAddress": "8.8.8.8", "ipAddressObservedAt": timestamp])
    await collector.record(["ipV6": "2001:db8::1", "ipV6ObservedAt": timestamp])
    await collector.record(["ipV4": "1.1.1.1", "ipV4ObservedAt": "2000-01-01T00:00:00.000Z"])
    await collector.record(["ipV6": "not-an-ip", "ipV6ObservedAt": timestamp])
    let attributes = await collector.attributes()
    #expect(attributes["ipV4"] == "8.8.8.8")
    #expect(attributes["ipV6"] == "2001:db8::1")
    #expect(attributes.count == 4)
  }

  @Test func acceptsTimestampsWithoutMilliseconds() async {
    let collector = DeviceIPCollector(url: nil, now: { date })
    let timestamp = ISO8601DateFormatter.string(from: date, timeZone: TimeZone(secondsFromGMT: 0)!, formatOptions: [.withInternetDateTime])
    #expect(!timestamp.contains("."))
    await collector.record(["ipV4": "8.8.8.8", "ipV4ObservedAt": timestamp])
    let attributes = await collector.attributes()
    #expect(attributes["ipV4"] == "8.8.8.8")
    #expect(attributes["ipV4ObservedAt"] == timestamp)
  }

  @Test func doesNotPairAnAddressWithAnotherFamilysTimestamp() async {
    let collector = DeviceIPCollector(url: nil, now: { date })
    await collector.record([
      "ipV6": "2001:db8::1",
      "ipAddress": "8.8.8.8",
      "ipAddressObservedAt": "2026-09-15T20:40:00Z"
    ])
    let attributes = await collector.attributes()
    #expect(attributes["ipV4"] == "8.8.8.8")
    #expect(attributes["ipV6"] == nil)
  }

  @Test func keepsTheNewerObservation() async {
    let collector = DeviceIPCollector(url: nil, now: { date })
    await collector.record(["ipV4": "8.8.8.8", "ipV4ObservedAt": "2026-09-15T20:40:00Z"])
    await collector.record(["ipV4": "1.1.1.1", "ipV4ObservedAt": "2026-09-15T20:39:00.500Z"])
    #expect(await collector.attributes()["ipV4"] == "8.8.8.8")
  }

  @Test func validatesNumericFamiliesWithoutDNS() {
    #expect(DeviceIPCollector.isValid("8.8.8.8", family: 4))
    #expect(!DeviceIPCollector.isValid("999.8.8.8", family: 4))
    #expect(!DeviceIPCollector.isValid("example.com", family: 6))
    #expect(!DeviceIPCollector.isValid("::ffff:8.8.8.8", family: 6))
  }

  @Test func parsesDeviceStringsAndSkipsOtherValues() throws {
    let data = Data(#"{"user":{},"device":{"ipAddress":"8.8.8.8","demandScore":42}}"#.utf8)
    let device = try DeviceIPCollector.parseDevice(from: data)
    #expect(device == ["ipAddress": "8.8.8.8"])
  }

  @Test func coalescesRefreshesWithoutWaitingForNetwork() async {
    let counter = FetchCounter()
    let collector = DeviceIPCollector(url: nil, fetch: { try await counter.fetch() }, now: { date })
    let first = await collector.refreshIfNeeded()
    let second = await collector.refreshIfNeeded()
    #expect(first != nil)
    #expect(second == nil)
    await first?.value
    #expect(await counter.count == 1)
  }

  private final class Clock: @unchecked Sendable {
    var date: Date
    init(_ date: Date) {
      self.date = date
    }
  }

  @Test func waitsAMinuteBeforeRetryingAFailedFetch() async {
    let counter = FetchCounter(shouldFail: true)
    let clock = Clock(date)
    let collector = DeviceIPCollector(url: nil, fetch: { try await counter.fetch() }, now: { clock.date })
    await collector.refreshIfNeeded()?.value

    clock.date = date.addingTimeInterval(30)
    #expect(await collector.refreshIfNeeded() == nil)

    await counter.setShouldFail(false)
    clock.date = date.addingTimeInterval(61)
    await collector.refreshIfNeeded()?.value
    #expect(await counter.count == 2)

    // A success waits out the full 15 minutes.
    clock.date = date.addingTimeInterval(61 + 14 * 60)
    #expect(await collector.refreshIfNeeded() == nil)
    clock.date = date.addingTimeInterval(61 + 15 * 60)
    #expect(await collector.refreshIfNeeded() != nil)
  }

  @Test func doesNothingWithoutAnEndpoint() async {
    let collector = DeviceIPCollector(url: nil, now: { date })
    #expect(await collector.refreshIfNeeded() == nil)
  }

  @Test func mmpFlagIsOffUnlessTheBackendTurnsItOn() throws {
    let decoder = JSONDecoder()
    let off = try decoder.decode(Attribution.self, from: Data(#"{"appleSearchAds":{"enabled":true}}"#.utf8))
    let on = try decoder.decode(Attribution.self, from: Data(#"{"mmp":{"enabled":true}}"#.utf8))
    #expect(off.mmp == nil)
    #expect(on.mmp?.enabled == true)
  }

  @Test func onlyReleaseEnvironmentsHaveAnIPv4Endpoint() {
    #expect(Api(networkEnvironment: .release).enrichment.ipV4Url?.absoluteString == "https://v4.superwall-enrichment.com/api/v1/enrich")
    #expect(Api(networkEnvironment: .releaseCandidate).enrichment.ipV4Url != nil)
    #expect(Api(networkEnvironment: .developer).enrichment.ipV4Url == nil)
    #expect(Api(networkEnvironment: .local).enrichment.ipV4Url == nil)
  }
}
