//
//  MMPInstallAttributionTests.swift
//  SuperwallKit
//
//  Tests for the MMP install-attribution gating logic in `Storage`.
//
// swiftlint:disable all

import Testing
import Foundation
@testable import SuperwallKit

@Suite
struct MMPInstallAttributionTests {
  private func makeStorage() -> Storage {
    Storage(
      factory: StorageMock.DeviceInfoFactoryMock(),
      cache: CacheMock()
    )
  }

  /// An ISO8601 install-date string offset from now.
  private func installDate(daysAgo: Double, fractionalSeconds: Bool = false) -> String {
    let date = Date().addingTimeInterval(-daysAgo * 24 * 60 * 60)
    let formatter = ISO8601DateFormatter()
    if fractionalSeconds {
      formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }
    return formatter.string(from: date)
  }

  // MARK: - Initial match

  @Test
  func initialMatch_freshInstallWithinWindow_returnsTrueAndMarksEligible() {
    let storage = makeStorage()

    let result = storage.shouldAttemptInitialMMPInstallAttributionMatch(
      hadTrackedAppInstallBeforeConfigure: false,
      appInstalledAtString: installDate(daysAgo: 1)
    )

    #expect(result == true)
    #expect(storage.get(IsEligibleForMMPInstallAttributionMatch.self) == true)
  }

  @Test
  func initialMatch_alreadyCompleted_returnsFalse() {
    let storage = makeStorage()
    storage.save(true, forType: DidCompleteMMPInstallAttributionRequest.self)

    let result = storage.shouldAttemptInitialMMPInstallAttributionMatch(
      hadTrackedAppInstallBeforeConfigure: false,
      appInstalledAtString: installDate(daysAgo: 1)
    )

    #expect(result == false)
  }

  @Test
  func initialMatch_upgraderWithoutEligibility_returnsFalse() {
    let storage = makeStorage()

    // Existing user upgrading the SDK: they tracked the install before this
    // version, and were never flagged eligible. They must not back-fill MMP.
    let result = storage.shouldAttemptInitialMMPInstallAttributionMatch(
      hadTrackedAppInstallBeforeConfigure: true,
      appInstalledAtString: installDate(daysAgo: 1)
    )

    #expect(result == false)
    #expect((storage.get(IsEligibleForMMPInstallAttributionMatch.self) ?? false) == false)
  }

  @Test
  func initialMatch_eligibleReturningSession_returnsTrue() {
    let storage = makeStorage()
    storage.save(true, forType: IsEligibleForMMPInstallAttributionMatch.self)

    // A returning session of a fresh install that was already flagged eligible
    // should still proceed even though the install was tracked previously.
    let result = storage.shouldAttemptInitialMMPInstallAttributionMatch(
      hadTrackedAppInstallBeforeConfigure: true,
      appInstalledAtString: installDate(daysAgo: 1)
    )

    #expect(result == true)
  }

  @Test
  func initialMatch_installOutsideWindow_returnsFalse() {
    let storage = makeStorage()

    let result = storage.shouldAttemptInitialMMPInstallAttributionMatch(
      hadTrackedAppInstallBeforeConfigure: false,
      appInstalledAtString: installDate(daysAgo: 8)
    )

    #expect(result == false)
  }

  @Test
  func initialMatch_emptyInstallDate_treatsWindowAsOpen() {
    let storage = makeStorage()

    let result = storage.shouldAttemptInitialMMPInstallAttributionMatch(
      hadTrackedAppInstallBeforeConfigure: false,
      appInstalledAtString: ""
    )

    #expect(result == true)
  }

  @Test
  func initialMatch_fractionalSecondsInstallDate_parsesWithinWindow() {
    let storage = makeStorage()

    let result = storage.shouldAttemptInitialMMPInstallAttributionMatch(
      hadTrackedAppInstallBeforeConfigure: false,
      appInstalledAtString: installDate(daysAgo: 1, fractionalSeconds: true)
    )

    #expect(result == true)
  }

  // MARK: - Tracking-permission (ATT) retry match

  @Test
  func trackingPermissionMatch_notEligible_returnsFalse() {
    let storage = makeStorage()

    let result = storage.shouldAttemptTrackingPermissionMMPInstallAttributionMatch(
      appInstalledAtString: installDate(daysAgo: 1)
    )

    #expect(result == false)
  }

  @Test
  func trackingPermissionMatch_eligibleWithinWindow_returnsTrue() {
    let storage = makeStorage()
    storage.save(true, forType: IsEligibleForMMPInstallAttributionMatch.self)

    let result = storage.shouldAttemptTrackingPermissionMMPInstallAttributionMatch(
      appInstalledAtString: installDate(daysAgo: 1)
    )

    #expect(result == true)
  }

  @Test
  func trackingPermissionMatch_runsEvenIfInitialRequestCompleted() {
    let storage = makeStorage()
    storage.save(true, forType: IsEligibleForMMPInstallAttributionMatch.self)
    storage.save(true, forType: DidCompleteMMPInstallAttributionRequest.self)

    // The ATT retry intentionally ignores the initial-request flag so it can
    // upgrade a probabilistic match into a deterministic one once a real IDFA
    // is available.
    let result = storage.shouldAttemptTrackingPermissionMMPInstallAttributionMatch(
      appInstalledAtString: installDate(daysAgo: 1)
    )

    #expect(result == true)
  }

  @Test
  func trackingPermissionMatch_alreadyCompletedAfterTracking_returnsFalse() {
    let storage = makeStorage()
    storage.save(true, forType: IsEligibleForMMPInstallAttributionMatch.self)
    storage.save(true, forType: DidCompleteMMPInstallAttributionRequestAfterTrackingPermission.self)

    let result = storage.shouldAttemptTrackingPermissionMMPInstallAttributionMatch(
      appInstalledAtString: installDate(daysAgo: 1)
    )

    #expect(result == false)
  }

  @Test
  func trackingPermissionMatch_outsideWindow_returnsFalse() {
    let storage = makeStorage()
    storage.save(true, forType: IsEligibleForMMPInstallAttributionMatch.self)

    let result = storage.shouldAttemptTrackingPermissionMMPInstallAttributionMatch(
      appInstalledAtString: installDate(daysAgo: 8)
    )

    #expect(result == false)
  }

  // MARK: - Reset (logout / new user)

  @Test
  func reset_preservesInstallScopedMMPState() {
    let storage = makeStorage()

    // Simulate a fully-resolved attribution for the previous user.
    storage.save(true, forType: IsEligibleForMMPInstallAttributionMatch.self)
    storage.save(true, forType: DidCompleteMMPInstallAttributionRequest.self)
    storage.save(true, forType: DidCompleteMMPInstallAttributionRequestAfterTrackingPermission.self)
    storage.save(["acquisition_source": JSON("facebook")], forType: MMPAcquisitionDataStorage.self)

    storage.reset()

    // MMP attribution is an install-scoped fact: the completion flags,
    // eligibility, and the cached `acquisition_*` payload all survive reset.
    // The new user is repopulated from the cache by
    // `Superwall.reset(duringIdentify:)`, not by re-running the backend match.
    #expect(storage.get(DidCompleteMMPInstallAttributionRequest.self) == true)
    #expect(storage.get(DidCompleteMMPInstallAttributionRequestAfterTrackingPermission.self) == true)
    #expect(storage.get(IsEligibleForMMPInstallAttributionMatch.self) == true)
    #expect(storage.get(MMPAcquisitionDataStorage.self)?["acquisition_source"]?.string == "facebook")
  }

  @Test
  func reset_doesNotReRunMatchForNewUser() {
    let storage = makeStorage()
    storage.save(true, forType: IsEligibleForMMPInstallAttributionMatch.self)
    storage.save(true, forType: DidCompleteMMPInstallAttributionRequest.self)

    storage.reset()

    // The completion flag is preserved across reset, so the new user does NOT
    // re-hit the backend even within the window — they're repopulated from the
    // cached payload instead. (A backend re-match would only reproduce the same
    // install-scoped result anyway.)
    #expect(
      storage.shouldAttemptInitialMMPInstallAttributionMatch(
        hadTrackedAppInstallBeforeConfigure: true,
        appInstalledAtString: installDate(daysAgo: 1)
      ) == false
    )
  }

  @Test
  func reset_afterWindowClosed_retainsCachedPayloadForNewUser() {
    let storage = makeStorage()
    storage.save(true, forType: IsEligibleForMMPInstallAttributionMatch.self)
    storage.save(true, forType: DidCompleteMMPInstallAttributionRequest.self)
    storage.save(["acquisition_source": JSON("facebook")], forType: MMPAcquisitionDataStorage.self)

    storage.reset()

    // Logout 8 days after install: the match window is closed, so re-matching
    // is impossible. The cached payload must survive so the new user can still
    // be repopulated — the previous clear-and-re-match approach left them empty
    // in exactly this case.
    #expect(
      storage.shouldAttemptInitialMMPInstallAttributionMatch(
        hadTrackedAppInstallBeforeConfigure: true,
        appInstalledAtString: installDate(daysAgo: 8)
      ) == false
    )
    #expect(storage.get(MMPAcquisitionDataStorage.self)?["acquisition_source"]?.string == "facebook")
  }

  // MARK: - Initial match request task

  @Test
  func recordInitialMatch_alreadyCompleted_returnsNilTask() {
    let storage = makeStorage()
    storage.save(true, forType: DidCompleteMMPInstallAttributionRequest.self)

    // No task is returned when the request already completed, so the ATT retry
    // has nothing to wait on.
    let task = storage.recordMMPInstallAttributionMatch { true }

    #expect(task == nil)
  }

  @Test
  func recordInitialMatch_notCompleted_returnsTaskAndPersistsOnSuccess() async {
    let storage = makeStorage()

    // The returned task lets the ATT retry await the initial match before
    // sending its upgraded request.
    let task = storage.recordMMPInstallAttributionMatch { true }
    #expect(task != nil)

    await task?.value
    #expect(storage.get(DidCompleteMMPInstallAttributionRequest.self) == true)
  }

  @Test
  func recordInitialMatch_failedRequest_doesNotPersistCompletion() async {
    let storage = makeStorage()

    let task = storage.recordMMPInstallAttributionMatch { false }
    await task?.value

    #expect((storage.get(DidCompleteMMPInstallAttributionRequest.self) ?? false) == false)
  }
}
