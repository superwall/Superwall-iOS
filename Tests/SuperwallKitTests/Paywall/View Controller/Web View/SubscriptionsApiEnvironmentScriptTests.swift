//
//  SubscriptionsApiEnvironmentScriptTests.swift
//  SuperwallKitTests
//

import Testing
@testable import SuperwallKit

struct SubscriptionsApiEnvironmentScriptTests {
  @Test("Points a developer SDK at the staging subscriptions-api")
  func developerIsStaging() {
    #expect(
      SubscriptionsApiEnvironmentScript.source(for: .developer)
        == #"window.__SW_SUBSCRIPTIONS_API_ENV__ = "staging";"#
    )
  }

  @Test("Points a local SDK at the local subscriptions-api")
  func localIsLocal() {
    #expect(
      SubscriptionsApiEnvironmentScript.source(for: .local)
        == #"window.__SW_SUBSCRIPTIONS_API_ENV__ = "local";"#
    )
  }

  @Test("Leaves paywall.js on its production default otherwise")
  func productionAndCustomInjectNothing() {
    #expect(SubscriptionsApiEnvironmentScript.source(for: .release) == nil)
    #expect(SubscriptionsApiEnvironmentScript.source(for: .releaseCandidate) == nil)
    #expect(SubscriptionsApiEnvironmentScript.source(for: .custom("https://example.com")) == nil)
  }
}
