// swiftlint:disable all
#if os(macOS)
import Foundation
import Testing
@testable import SuperwallKit

struct MacDeviceInfoTests {
  @Test
  func installationIdentifierSurvivesReopeningDefaults() throws {
    let suite = "MacDeviceInfoTests.\(UUID().uuidString)"
    let first = try #require(UserDefaults(suiteName: suite))
    defer { first.removePersistentDomain(forName: suite) }
    let identifier = MacDeviceInfo.vendorId(in: first)
    #expect(UUID(uuidString: identifier) != nil)
    let reopened = try #require(UserDefaults(suiteName: suite))
    #expect(MacDeviceInfo.vendorId(in: reopened) == identifier)
    first.removePersistentDomain(forName: suite)
    #expect(MacDeviceInfo.vendorId(in: first) != identifier)
  }

  @Test
  func concurrentFirstReadsShareOneInstallationIdentifier() throws {
    let suite = "MacDeviceInfoTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let lock = NSLock()
    var identifiers: Set<String> = []
    DispatchQueue.concurrentPerform(iterations: 32) { _ in
      let identifier = MacDeviceInfo.vendorId(in: defaults)
      lock.lock()
      identifiers.insert(identifier)
      lock.unlock()
    }
    #expect(identifiers.count == 1)
    #expect(identifiers.first == MacDeviceInfo.vendorId(in: defaults))
  }

  @Test
  func appearanceUsesExistingBackendTokens() {
    #expect(MacDeviceInfo.interfaceStyleToken(isDark: true) == "Dark")
    #expect(MacDeviceInfo.interfaceStyleToken(isDark: false) == "Light")
    #expect(!MacDeviceInfo.model.isEmpty)
  }
}
#endif
