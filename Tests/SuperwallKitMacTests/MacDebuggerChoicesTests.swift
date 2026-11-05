// swiftlint:disable all
#if os(macOS)
import Testing
@testable import SuperwallKit

import Foundation

private func surface(id: String) -> DevServerSurface {
  let json = #"{"kind": "paywall", "id": "\#(id)", "url": "/preview/paywall/\#(id)"}"#
  return try! JSONDecoder().decode(DevServerSurface.self, from: Data(json.utf8))
}

@Suite
struct MacDebuggerChoicesTests {
  private let local = MacDebugger.localChoice(surface(id: "onboarding"))

  @Test
  func localChoiceUsesTheSurfacePreviewIdentifier() {
    #expect(local == MacDebugger.Choice(id: "dev:onboarding", name: "Local: onboarding", identifier: "dev:onboarding"))
  }

  @Test
  func fallbackOffersTheConfigPaywallsAfterTheLocalSurfaces() {
    let choices = MacDebugger.fallbackChoices(
      local: [local],
      configPaywalls: [PaywallSummary(id: "123", identifier: "pro-paywall", name: "Pro")]
    )

    #expect(choices == [
      local,
      MacDebugger.Choice(id: "123", name: "Pro", identifier: "pro-paywall")
    ])
  }

  @Test
  func fallbackWithAnEmptyConfigKeepsTheLocalSurfaces() {
    #expect(MacDebugger.fallbackChoices(local: [local], configPaywalls: []) == [local])
  }

  @Test
  func linkedPaywallInConfigIsNotLookedUpAgain() {
    let choices = MacDebugger.fallbackChoices(
      local: [],
      configPaywalls: [PaywallSummary(id: "123", identifier: "pro-paywall", name: "Pro")]
    )
    #expect(MacDebugger.linkedPaywallToLookUp("123", in: choices) == nil)
  }

  @Test
  func localSurfaceAndPublishedPaywallWithTheSameIdStayApart() {
    let local = MacDebugger.localChoice(surface(id: "123"))
    let choices = MacDebugger.fallbackChoices(
      local: [local],
      configPaywalls: [PaywallSummary(id: "123", identifier: "pro-paywall", name: "Pro")]
    )

    #expect(Set(choices.map(\.id)).count == 2)
    // A dashboard link selects the published paywall, a local link the surface.
    #expect(MacDebugger.initialSelection(in: choices, linkedSurface: nil, linkedPaywallId: "123") == "123")
    #expect(MacDebugger.initialSelection(in: choices, linkedSurface: "dev:123", linkedPaywallId: nil) == "dev:123")
    #expect(MacDebugger.initialSelection(in: choices, linkedSurface: nil, linkedPaywallId: nil) == "dev:123")
  }

  @Test
  func linkedPaywallMissingFromConfigIsLookedUp() {
    let choices = MacDebugger.fallbackChoices(local: [local], configPaywalls: [])
    #expect(MacDebugger.linkedPaywallToLookUp("456", in: choices) == "456")
    #expect(MacDebugger.linkedPaywallToLookUp(nil, in: choices) == nil)
  }

  @Test
  func linkedSurfaceMissingFromTheManifestIsReported() {
    let message = MacDebugger.missingLinkMessage(
      surfaceId: "paywall-b",
      in: [surface(id: "onboarding")],
      paywallId: nil,
      in: [local]
    )
    #expect(message?.contains("paywall-b") == true)
  }

  @Test
  func linkedPaywallMissingFromTheChoicesIsReported() {
    let message = MacDebugger.missingLinkMessage(
      surfaceId: nil,
      in: [surface(id: "onboarding")],
      paywallId: "456",
      in: [local]
    )
    #expect(message?.contains("456") == true)
  }

  @Test
  func linksThatAreOfferedNeedNoMessage() {
    let published = MacDebugger.Choice(id: "456", name: "Pro", identifier: "pro")
    #expect(MacDebugger.missingLinkMessage(
      surfaceId: "onboarding",
      in: [surface(id: "onboarding")],
      paywallId: nil,
      in: [local, published]
    ) == nil)
    #expect(MacDebugger.missingLinkMessage(
      surfaceId: nil,
      in: [surface(id: "onboarding")],
      paywallId: "456",
      in: [local, published]
    ) == nil)
  }
}
#endif
