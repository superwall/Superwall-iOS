import Testing
import Foundation
import SwiftUI
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
    #expect(config.support.warnsAboutUpdates == true)
    #expect(config.showsAccountDetails && config.warnsAboutDuplicateSubscriptions)
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
    config.managementScreen.paths.append(.init(id: "faq", type: .url(URL(string: "https://app.com/faq")!, openMethod: .inApp)))
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

  @Test("a path without an id takes one from its type, URL or custom identifier")
  func pathIdDefaults() {
    typealias Path = CustomerCenterConfiguration.Path
    #expect(Path(type: .restore).id == "restore")
    #expect(Path(type: .manageSubscription).id == "manage_subscription")
    #expect(Path(type: .refund(window: 3600)).id == "refund")
    #expect(Path(type: .changePlan(productIds: ["a"])).id == "change_plan")
    #expect(Path(type: .contactSupport).id == "contact_support")
    let faq = URL(string: "https://app.com/faq")!
    #expect(Path(type: .url(faq, openMethod: .inApp)).id == "app.com/faq")
    let tokenURL = URL(string: "https://app.com/account?token=secret#top")!
    #expect(Path(type: .url(tokenURL)).id == "app.com/account", "a query can carry a token, so it stays out of the id")
    #expect(Path(type: .custom(identifier: "delete_account")).id == "delete_account")
    #expect(Path(id: "refund_30_days", type: .refund(window: 2_592_000)).id == "refund_30_days")
    #expect(Path.refund.id == "refund")
  }

  @Test("a path decoded without an id takes the default one")
  func decodedPathIdDefaults() throws {
    let encoded = try JSONEncoder().encode(CustomerCenterConfiguration.Path(id: "ignored", type: .restore))
    var json = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    json.removeValue(forKey: "id")
    let data = try JSONSerialization.data(withJSONObject: json)
    let decoded = try JSONDecoder().decode(CustomerCenterConfiguration.Path.self, from: data)
    #expect(decoded.id == "restore")
    #expect(decoded.type == .restore)
  }

  @Test("repeated path ids are found per screen, not across screens")
  func duplicatePathIds() {
    let config = CustomerCenterConfiguration.default
    #expect(config.duplicatePathIds.isEmpty, "restore on both screens is fine")
    config.managementScreen.paths.append(.init(type: .refund(window: 60)))
    #expect(config.duplicatePathIds == ["refund"])
    config.managementScreen.paths.removeLast()
    config.managementScreen.paths.append(.init(id: "refund_short", type: .refund(window: 60)))
    #expect(config.duplicatePathIds.isEmpty)
  }

  @Test("URL paths without a title are reported")
  func untitledURLPaths() {
    let config = CustomerCenterConfiguration.default
    let faq = URL(string: "https://app.com/faq")!
    config.managementScreen.paths.append(.url(faq, title: "FAQ", id: "faq"))
    #expect(config.untitledURLPathIds.isEmpty)
    config.managementScreen.paths.append(.init(id: "terms", type: .url(faq)))
    #expect(config.untitledURLPathIds == ["terms"])
  }

  @Test("path shorthands build the same paths as Path(type:)")
  func pathShorthands() {
    typealias Path = CustomerCenterConfiguration.Path
    let faq = URL(string: "https://app.com/faq")!
    let survey = CustomerCenterConfiguration.FeedbackSurvey(id: "s", title: nil, options: [.init(id: "a", title: nil)])
    let screen = CustomerCenterConfiguration.Screen(paths: [
      .restore,
      .changePlan(productIds: ["a", "b"]),
      .refund(window: 3600),
      .manageSubscription(survey: survey),
      .url(faq, title: "FAQ"),
      .custom(identifier: "delete_account", title: "Delete account"),
      .contactSupport
    ])
    #expect(screen.paths == [
      Path(type: .restore),
      Path(type: .changePlan(productIds: ["a", "b"])),
      Path(type: .refund(window: 3600)),
      Path(type: .manageSubscription, survey: survey),
      Path(type: .url(faq, openMethod: .inApp), title: "FAQ"),
      Path(type: .custom(identifier: "delete_account"), title: "Delete account"),
      Path(type: .contactSupport)
    ])
    #expect(Path.refund == Path(type: .refund()))
    #expect(Path.changePlan == Path(type: .changePlan()))
    #expect(Path.manageSubscription == Path(type: .manageSubscription))
    #expect(Path.url(faq, title: "FAQ", openMethod: .external).type == .url(faq, openMethod: .external))
    #expect(Path.refund(window: 60, id: "refund_short").id == "refund_short")
  }

  @Test("the cancellation survey is the default configuration's survey, built from named options")
  func cancellationSurvey() {
    let manage = CustomerCenterConfiguration.default.managementScreen.paths.first { $0.id == "manage_subscription" }
    #expect(manage?.survey == .cancellation)
    #expect(CustomerCenterConfiguration.FeedbackSurvey.cancellation.options.map(\.id) == ["too_expensive", "dont_use", "bought_by_mistake"])
    #expect(CustomerCenterConfiguration.FeedbackSurvey.cancellation.title == nil)
    #expect(CustomerCenterConfiguration.FeedbackSurvey.Option.tooExpensive.title == nil)
  }

  @Test("an untitled survey is reported unless it's on the manage-subscription path")
  func untitledSurveys() {
    let config = CustomerCenterConfiguration.default
    #expect(config.untitledSurveyPathIds.isEmpty, "the default question fits the cancel path")
    config.managementScreen.paths.append(.refund(window: 60, id: "refund_short", survey: .cancellation))
    #expect(config.untitledSurveyPathIds == ["refund_short"])
  }

  @Test("colour pairs accept SwiftUI colours and malformed hex is reported")
  func accentColours() {
    let pair = CustomerCenterConfiguration.Appearance.ColorPair(
      light: Color(red: 1, green: 0, blue: 0),
      dark: Color(red: 0, green: 0, blue: 1)
    )
    #expect(pair.light == "#FF0000FF")
    #expect(pair.dark == "#0000FFFF")

    let config = CustomerCenterConfiguration.default
    config.appearance.accent = .init(light: "#112233", dark: "not a colour")
    #expect(config.invalidAccentHexes == ["not a colour"])
  }

  @Test("navigation options show a close button only for a sheet, unless told otherwise")
  @available(iOS 15.0, *)
  func navigationOptionDefaults() {
    #expect(CustomerCenterNavigationOptions().showsCloseButton)
    #expect(!CustomerCenterNavigationOptions(style: .embedded).showsCloseButton)
    #expect(CustomerCenterNavigationOptions(style: .embedded, showsCloseButton: true).showsCloseButton)
    #expect(CustomerCenterNavigationOptions(style: .embedded).usesExistingNavigation)
  }
}

