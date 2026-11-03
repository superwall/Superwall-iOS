// swiftlint:disable all
#if os(macOS)
import Testing
@testable import SuperwallKit

@Suite
struct MacDebuggerChoicesTests {
  private let local = MacDebugger.localChoice(surfaceId: "onboarding", previewIdentifier: "dev:onboarding")

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
    let local = MacDebugger.localChoice(surfaceId: "123", previewIdentifier: "dev:123")
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
}
#endif
