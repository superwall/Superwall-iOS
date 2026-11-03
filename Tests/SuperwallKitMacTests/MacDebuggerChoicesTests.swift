// swiftlint:disable all
#if os(macOS)
import Testing
@testable import SuperwallKit

@Suite
struct MacDebuggerChoicesTests {
  private let local = MacDebugger.Choice(id: "onboarding", name: "Local: onboarding", identifier: "dev:onboarding")

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
  func linkedPaywallMissingFromConfigIsLookedUp() {
    let choices = MacDebugger.fallbackChoices(local: [local], configPaywalls: [])
    #expect(MacDebugger.linkedPaywallToLookUp("456", in: choices) == "456")
    #expect(MacDebugger.linkedPaywallToLookUp(nil, in: choices) == nil)
  }
}
#endif
