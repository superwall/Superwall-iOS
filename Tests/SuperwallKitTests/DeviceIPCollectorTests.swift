import Foundation
import Testing
@testable import SuperwallKit

struct DeviceIPCollectorTests {
  private let date = Date(timeIntervalSince1970: 1_789_505_000)

  @Test func keepsFamiliesSeparateAndRejectsStaleOrInvalidObservations() async {
    let collector = DeviceIPCollector(fetch: { [:] }, now: { date })
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

  @Test func validatesNumericFamiliesWithoutDNS() {
    #expect(DeviceIPCollector.isValid("8.8.8.8", family: 4))
    #expect(!DeviceIPCollector.isValid("999.8.8.8", family: 4))
    #expect(!DeviceIPCollector.isValid("example.com", family: 6))
    #expect(!DeviceIPCollector.isValid("::ffff:8.8.8.8", family: 6))
  }

  @Test func coalescesRefreshesWithoutWaitingForNetwork() async {
    actor FetchCounter {
      var count = 0
      func fetch() async -> [String: String] {
        count += 1
        try? await Task.sleep(nanoseconds: 100_000_000)
        return [:]
      }
    }
    let counter = FetchCounter()
    let collector = DeviceIPCollector(fetch: { await counter.fetch() }, now: { date })
    await collector.refreshIfNeeded()
    await collector.refreshIfNeeded()
    #expect(await collector.attributes().isEmpty)
    try? await Task.sleep(nanoseconds: 150_000_000)
    #expect(await counter.count == 1)
  }
}
