import Foundation
import Testing
@testable import SuperwallKit

struct DeepLinkEnrichmentTests {
  @Test("Enrichment forwards the unmodified original URL and its resolved destination")
  func requestPreservesBothURLs() throws {
    let original = try #require(URL(string: "https://app.superwall.app/app-link/welcome?ref=a%2Fb#offer"))
    let resolved = try #require(URL(string: "app://welcome?ref=a%2Fb#offer"))
    let request = EnrichmentRequest(
      user: JSON([:]),
      device: JSON([:]),
      deepLink: .init(originalURL: original, resolvedURL: resolved)
    )
    let data = try EndpointKinds.Superwall.jsonEncoder.encode(request)
    let body = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let context = try #require(body["deep_link"] as? [String: String])
    #expect(context["original_url"] == original.absoluteString)
    #expect(context["resolved_url"] == resolved.absoluteString)
  }

  @Test("Ordinary enrichment requests omit deep-link context")
  func ordinaryRequestOmitsContext() throws {
    let request = EnrichmentRequest(user: JSON([:]), device: JSON([:]))
    let data = try EndpointKinds.Superwall.jsonEncoder.encode(request)
    let body = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    #expect(body["deep_link"] == nil)
    // The existing response/cache contract is unchanged.
    let response = try JSONDecoder().decode(Enrichment.self, from: data)
    #expect(response.user.dictionaryObject?.isEmpty == true)
  }

  @Test("Deep-link enrichment finishes before the placement event is tracked")
  func enrichmentPrecedesTracking() async throws {
    let container = DependencyContainer()
    let router = try #require(container.deepLinkRouter)
    let trace = Trace()
    let started = Gate()
    let release = Gate()
    let tracked = Gate()
    router.enrichDeepLink = { context in
      await trace.enrich(context)
      await started.open()
      await release.wait()
      await trace.finish()
    }
    router.trackEvent = { event in
      await trace.track(event)
      await tracked.open()
    }
    let url = try #require(URL(string: "myapp://welcome?cpp_id=page-1"))
    _ = router.route(url: url)
    await started.wait()
    #expect(await trace.steps == ["enrichment"])
    await release.open()
    await tracked.wait()
    #expect(await trace.steps == ["enrichment", "applied", "track"])
    #expect(await trace.context == .init(originalURL: url, resolvedURL: url))
    #expect(await trace.eventURL == url)
    withExtendedLifetime(container) {}
  }

  @Test("A failed enrichment lookup still tracks the resolved deep link")
  func failureContinuesTracking() async throws {
    let container = DependencyContainer()
    let router = try #require(container.deepLinkRouter)
    let trace = Trace()
    let tracked = Gate()
    router.enrichDeepLink = { context in
      await trace.enrich(context)
      throw LookupFailure.unavailable
    }
    router.trackEvent = { event in
      await trace.track(event)
      await tracked.open()
    }
    let original = try #require(URL(string: "https://myapp.superwall.app/app-link/welcome?ref=a%2Fb"))
    let resolved = try #require(URL(string: "myapp://welcome?ref=a%2Fb"))
    #expect(router.route(url: original))
    await tracked.wait()
    #expect(await trace.steps == ["enrichment", "track"])
    #expect(await trace.context == .init(originalURL: original, resolvedURL: resolved))
    #expect(await trace.eventURL == resolved)
    withExtendedLifetime(container) {}
  }

  @Test("Superwall return links skip acquisition enrichment")
  func returnLinkSkipsEnrichment() async throws {
    let container = DependencyContainer()
    let router = try #require(container.deepLinkRouter)
    let trace = Trace()
    let tracked = Gate()
    router.enrichDeepLink = { await trace.enrich($0) }
    router.presentedPaywallInfo = { nil }
    router.trackEvent = { event in
      await trace.track(event)
      await tracked.open()
    }
    let url = try #require(URL(string: "myapp://superwall/return"))
    #expect(router.route(url: url))
    await tracked.wait()
    #expect(await trace.context == nil)
    #expect(await trace.steps == ["track"])
    withExtendedLifetime(container) {}
  }

  private enum LookupFailure: Error {
    case unavailable
  }

  private actor Trace {
    var steps: [String] = []
    var context: EnrichmentRequest.DeepLink?
    var eventURL: URL?

    func enrich(_ context: EnrichmentRequest.DeepLink) {
      self.context = context
      steps.append("enrichment")
    }

    func finish() {
      steps.append("applied")
    }

    func track(_ event: Trackable) {
      eventURL = (event as? InternalSuperwallEvent.DeepLink)?.url
      steps.append("track")
    }
  }

  private actor Gate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
      if isOpen { return }
      await withCheckedContinuation { waiters.append($0) }
    }

    func open() {
      isOpen = true
      let pending = waiters
      waiters.removeAll()
      for waiter in pending { waiter.resume() }
    }
  }
}
