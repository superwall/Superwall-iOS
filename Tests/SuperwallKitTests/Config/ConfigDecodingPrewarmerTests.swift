import Foundation
import Testing
@testable import SuperwallKit

struct ConfigDecodingPrewarmerTests {
  @Test func fixtureExercisesConfigRulePaywallAndProducts() throws {
    let config = try JSONDecoder.fromSnakeCase.decode(
      Config.self,
      from: Data(ConfigDecodingPrewarmer.fixture.utf8)
    )
    let trigger = try #require(config.triggers.first)
    let rule = try #require(trigger.audiences.first)
    let paywall = try #require(config.paywalls.first)
    #expect(config.triggers.count == 1)
    #expect(trigger.placementName == "configDecoder_prewarm")
    #expect(trigger.audiences.count == 1)
    #expect(rule.experiment.variants.count == 1)
    #expect(rule.experiment.variants.first?.paywallId == paywall.identifier)
    #expect(config.paywalls.count == 1)
    #expect(paywall.presentation.style == .fullscreen)
    #expect(paywall.url.host == "config-prewarm.invalid")
    #expect(config.products.count == 2)
    #expect(paywall.products.count == 2)
    #expect(Set(config.products.map(\.id)) == Set(paywall.products.map(\.id)))
    for product in config.products + paywall.products {
      guard case .appStore = product.type else {
        Issue.record("The fixture product was silently dropped or decoded as another store")
        continue
      }
      #expect(product.entitlements.map(\.id) == ["prewarm"])
    }
    #expect(config.locales == ["en"])
    #expect(config.preloadingDisabled.all)
    #expect(config.attribution?.appleSearchAds?.enabled == false)
    #expect(config.web2appConfig?.restoreAccessURL.host == "config-prewarm.invalid")
  }

  @Test func concurrentStartsScheduleOnlyOneBackgroundDecodeWithoutWaiting() {
    let queue = DispatchQueue(label: "config-prewarm-test", qos: .utility)
    let state = State()
    let finished = DispatchSemaphore(value: 0)
    queue.suspend()
    let prewarmer = ConfigDecodingPrewarmer(
      schedule: { work in
        state.lock.lock()
        state.scheduled += 1
        state.lock.unlock()
        queue.async(execute: work)
      },
      decode: {
        #expect(!Thread.isMainThread)
        state.lock.lock()
        state.decoded += 1
        state.lock.unlock()
        finished.signal()
      }
    )
    DispatchQueue.concurrentPerform(iterations: 100) { _ in prewarmer.start() }
    #expect(state.scheduled == 1)
    #expect(state.decoded == 0, "Starting must return while the background queue is suspended")
    queue.resume()
    #expect(finished.wait(timeout: .now() + 2) == .success)
    queue.sync {}
    #expect(state.decoded == 1)
    prewarmer.start()
    queue.sync {}
    #expect(state.scheduled == 1)
  }

  @Test func invalidWarmupIsIgnoredAndIsNotRepeated() {
    enum FixtureError: Error { case invalid }
    var decodeCount = 0
    let prewarmer = ConfigDecodingPrewarmer(
      schedule: { $0() },
      decode: {
        decodeCount += 1
        throw FixtureError.invalid
      }
    )
    prewarmer.start()
    prewarmer.start()
    #expect(decodeCount == 1)
  }

  private final class State {
    let lock = NSLock()
    var scheduled = 0
    var decoded = 0
  }
}
