//
//  StandardEventPlacementTests.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 2026-11-04.
//

@testable import SuperwallKit
import Foundation
import Testing

/// Placements named after a standard Superwall event are rejected, so they
/// can't trigger campaigns meant for that event or show up as it in analytics.
@Suite(.serialized)
struct StandardEventPlacementTests {
  @Test func register_withStandardEventName_reportsAnErrorAndSkipsTheFeature() async {
    let superwall = Superwall(dependencyContainer: DependencyContainer(cache: CacheMock()))
    let featureCalls = FeatureCallCounter()

    let error: Error? = await withCheckedContinuation { continuation in
      let handler = PaywallPresentationHandler()
      handler.onError { error in
        continuation.resume(returning: error)
      }
      superwall.register(placement: "app_launch", handler: handler) {
        featureCalls.count += 1
      }
    }

    let nsError = error as NSError?
    #expect(nsError?.code == 400)
    #expect(nsError?.localizedDescription.contains("app_launch") == true)
    // Both callbacks run on the main queue, so the feature would have run by now.
    #expect(featureCalls.count == 0)
  }

  @MainActor
  @Test func getPaywall_withStandardEventName_throws() async {
    let superwall = Superwall(dependencyContainer: DependencyContainer(cache: CacheMock()))
    let delegate = PaywallFinishRecorder()

    do {
      _ = try await superwall.getPaywall(forPlacement: "paywall_open", delegate: delegate)
      Issue.record("Expected getPaywall to throw")
    } catch {
      let nsError = error as NSError
      #expect(nsError.code == 400)
      #expect(nsError.localizedDescription.contains("paywall_open"))
    }
  }

  @Test func checkNotSuperwallEvent_rejectsEveryStandardEventName() {
    for event in SuperwallEventObjc.allCases {
      #expect(throws: (any Error).self) {
        try TrackingLogic.checkNotSuperwallEvent(event.description)
      }
    }
  }
}

/// Counts calls to a `register` feature block. Only touched on the main queue.
private final class FeatureCallCounter: @unchecked Sendable {
  var count = 0
}
