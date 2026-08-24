import Testing
import Foundation
@testable import SuperwallKit

@Suite("CustomerCenterConfiguration")
struct CustomerCenterConfigurationTests {
  @Test("default has management paths restore/changePlan/refund/manage(with survey)/contactSupport and no-purchases restore")
  func defaultShape() {
    let config = CustomerCenterConfiguration.default
    #expect(config.managementScreen.paths.map(\.id) == ["restore", "change_plan", "refund", "manage_subscription", "contact_support"])
    #expect(config.noPurchasesScreen.paths.map(\.id) == ["restore"])
    let manage = config.managementScreen.paths[3]
    #expect(manage.type == .manageSubscription)
    #expect(manage.survey?.id == "cancel_survey")
    #expect(manage.survey?.options.map(\.id) == ["too_expensive", "dont_use", "bought_by_mistake"])
    #expect(config.support.email == nil)
    #expect(config.support.shouldWarnToUpdate == true)
    #expect(config.showsPurchaseHistory && config.showsAccountDetails && config.warnsAboutDuplicateSubscriptions)
  }

  @Test("default returns a fresh instance each time")
  func defaultIsFresh() {
    let a = CustomerCenterConfiguration.default
    a.support.email = "x@y.z"
    #expect(CustomerCenterConfiguration.default.support.email == nil)
  }

  @Test("round-trips through JSON including PathType payloads")
  func codableRoundTrip() throws {
    let config = CustomerCenterConfiguration.default
    config.support.email = "help@app.com"
    config.support.latestAppVersion = "2.1.0"
    config.support.webManagementURL = URL(string: "https://app.superwall.app/manage")
    config.appearance.accent = .init(light: "#112233", dark: "#AABBCC")
    config.managementScreen.paths.append(.init(id: "faq", type: .url(URL(string: "https://app.com/faq")!, openMethod: .inApp), title: "FAQ"))
    config.managementScreen.paths.append(.init(id: "del", type: .custom(identifier: "delete_account")))
    config.managementScreen.paths.append(.init(id: "ref", type: .refund(window: 3600)))
    config.managementScreen.paths.append(.init(id: "chg", type: .changePlan(productIds: ["a", "b"])))

    let data = try JSONEncoder().encode(config)
    let decoded = try JSONDecoder().decode(CustomerCenterConfiguration.self, from: data)
    #expect(decoded == config)
    #expect(decoded.managementScreen.paths.last?.type == .changePlan(productIds: ["a", "b"]))
  }

  @Test("equal configurations hash equally, including after a Codable round-trip")
  func hashMatchesEquality() throws {
    let config = CustomerCenterConfiguration.default
    config.support.email = "help@app.com"
    config.support.latestAppVersion = "2.1.0"
    config.appearance.accent = .init(light: "#112233", dark: "#AABBCC")

    // Decoding creates distinct instances, so identity-based hashing would diverge here even
    // though the values compare equal.
    let data = try JSONEncoder().encode(config)
    let decoded = try JSONDecoder().decode(CustomerCenterConfiguration.self, from: data)
    #expect(decoded == config)
    #expect(decoded.hash == config.hash)
    #expect(decoded.support.hash == config.support.hash)
    #expect(decoded.appearance.hash == config.appearance.hash)
    #expect(decoded.appearance.accent?.hash == config.appearance.accent?.hash)
  }

  @Test("SuperwallOptions exposes a default customerCenter configuration")
  func optionsDefault() {
    let options = SuperwallOptions()
    #expect(options.customerCenter == CustomerCenterConfiguration.default)
    options.customerCenter.support.email = "a@b.c"
    #expect(options.customerCenter.support.email == "a@b.c")
  }
}
