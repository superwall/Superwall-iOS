//
//  IdentityResetHandlingTests.swift
//  SuperwallKit
//
//  Created by Superwall on 05/11/2026.
//
// swiftlint:disable all

import Foundation
import Testing
@testable import SuperwallKit

@Suite("Superwall as the identity's reset handler")
struct IdentityResetHandlingTests {
  @Test("The new user keeps ASA, MMP and install-scoped integration attributes")
  func keepsEveryInstallScopedSource() {
    let kept = Superwall.attributesKeptAcrossReset(
      adServicesAttribution: ["campaignId": 1234],
      acquisitionAttributes: ["acquisition_source": "network"],
      integrationAttributes: ["appsflyerId": "af-1", "idfv": "vendor-1", "idfa": NSNull()]
    )

    #expect(kept["campaignId"] as? Int == 1234)
    #expect(kept["acquisition_source"] as? String == "network")
    #expect(kept["appsflyerId"] as? String == "af-1")
    #expect(kept["idfv"] as? String == "vendor-1")
    // An explicit null clears an IDFA kept from before consent was revoked.
    #expect(kept["idfa"] as? NSNull != nil)
  }

  @Test("Later sources win a clash")
  func laterSourcesWin() {
    let kept = Superwall.attributesKeptAcrossReset(
      adServicesAttribution: ["shared": "ads"],
      acquisitionAttributes: ["shared": "mmp"],
      integrationAttributes: ["shared": "integration"]
    )
    #expect(kept["shared"] as? String == "integration")

    let withoutIntegration = Superwall.attributesKeptAcrossReset(
      adServicesAttribution: ["shared": "ads"],
      acquisitionAttributes: ["shared": "mmp"],
      integrationAttributes: [:]
    )
    #expect(withoutIntegration["shared"] as? String == "mmp")
  }

  @Test("Kept attributes are cleaned as setUserAttributes cleans them")
  func keptAttributesAreSanitized() {
    let kept = Superwall.attributesKeptAcrossReset(
      adServicesAttribution: ["$reserved": "x", "date": Date()],
      acquisitionAttributes: ["email": "not-an-email"],
      integrationAttributes: ["valid": "y"]
    )

    #expect(kept.keys.contains("$reserved") == false)
    #expect(kept.keys.contains("date") == false)
    #expect(kept["valid"] as? String == "y")
    // An invalid email is sent as null, as setUserAttributes sends it.
    #expect(kept.keys.contains("email"))
    #expect(kept["email"]! == nil)
  }

  @Test("Nothing cached means nothing kept")
  func nothingKept() {
    let kept = Superwall.attributesKeptAcrossReset(
      adServicesAttribution: [:],
      acquisitionAttributes: [:],
      integrationAttributes: [:]
    )
    #expect(kept.isEmpty)
  }

  @Test("Superwall registers itself as its identity's reset handler")
  func superwallIsTheResetHandler() {
    let dependencyContainer = DependencyContainer()
    let superwall = Superwall(dependencyContainer: dependencyContainer)
    #expect(dependencyContainer.identityManager.resetHandler === superwall)
  }
}
