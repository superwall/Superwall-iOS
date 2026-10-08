//
//  AdConsentTests.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 08/10/2026.
//

@testable import SuperwallKit
import Testing
import Foundation
import UIKit

struct AdConsentTests {
  @Test func defaults_areGranted() {
    let consent = AdConsent()
    #expect(consent.adUserData == .granted)
    #expect(consent.adPersonalization == .granted)

    let options = SuperwallOptions()
    #expect(options.adConsent.adUserData == .granted)
    #expect(options.adConsent.adPersonalization == .granted)
  }

  @Test func init_defaultsUnspecifiedPurposesToGranted() {
    let consent = AdConsent(adUserData: .denied)
    #expect(consent.adUserData == .denied)
    #expect(consent.adPersonalization == .granted)
  }

  @Test func consentStatus_descriptionsMatchTheServerContract() {
    #expect(AdConsentStatus.granted.description == "granted")
    #expect(AdConsentStatus.denied.description == "denied")
  }

  @Test func templateDevice_reportsGrantedByDefault() async {
    let dependencyContainer = DependencyContainer(cache: CacheMock())
    let deviceHelper = makeDeviceHelper(dependencyContainer, attStatus: .notDetermined)

    let template = await deviceHelper.getTemplateDevice()

    #expect(template["adUserDataConsent"] as? String == "granted")
    #expect(template["adPersonalizationConsent"] as? String == "granted")
    withExtendedLifetime(dependencyContainer) {}
  }

  @Test func settingAdConsentAtRuntime_isReflectedInDeviceAttributes() async {
    let dependencyContainer = DependencyContainer(cache: CacheMock())
    let superwall = Superwall(dependencyContainer: dependencyContainer)
    let deviceHelper = makeDeviceHelper(dependencyContainer, attStatus: .authorized)

    superwall.adConsent = AdConsent(adUserData: .denied, adPersonalization: .granted)

    #expect(dependencyContainer.configManager.options.adConsent.adUserData == .denied)
    let template = await deviceHelper.getTemplateDevice()
    #expect(template["adUserDataConsent"] as? String == "denied")
    #expect(template["adPersonalizationConsent"] as? String == "granted")

    superwall.adConsent = AdConsent(adUserData: .granted, adPersonalization: .denied)

    let updated = await deviceHelper.getTemplateDevice()
    #expect(updated["adUserDataConsent"] as? String == "granted")
    #expect(updated["adPersonalizationConsent"] as? String == "denied")
  }

  @Test func eventTrackingBehaviorNone_reportsDenied() async {
    let dependencyContainer = DependencyContainer(cache: CacheMock())
    let deviceHelper = makeDeviceHelper(dependencyContainer, attStatus: .authorized)
    let options = dependencyContainer.configManager.options
    options.adConsent = AdConsent(adUserData: .granted, adPersonalization: .granted)
    options.eventTrackingBehavior = .none

    let template = await deviceHelper.getTemplateDevice()

    #expect(template["adUserDataConsent"] as? String == "denied")
    #expect(template["adPersonalizationConsent"] as? String == "denied")
    // The developer's choice itself is left untouched.
    #expect(options.adConsent.adUserData == .granted)
    #expect(options.adConsent.adPersonalization == .granted)
  }

  @Test(arguments: [FakeTrackingAuthorizationStatus.denied, .restricted])
  func attNotAllowed_deniesPersonalizationOnly(_ attStatus: FakeTrackingAuthorizationStatus) async {
    let dependencyContainer = DependencyContainer(cache: CacheMock())
    let deviceHelper = makeDeviceHelper(dependencyContainer, attStatus: attStatus)
    let options = dependencyContainer.configManager.options
    options.adConsent = AdConsent(adUserData: .granted, adPersonalization: .granted)

    let template = await deviceHelper.getTemplateDevice()

    #expect(template["adUserDataConsent"] as? String == "granted")
    #expect(template["adPersonalizationConsent"] as? String == "denied")
    // The stored option, which `config_attributes` reports, is left untouched.
    #expect(options.adConsent.adPersonalization == .granted)
    #expect(options.toDictionary()["adPersonalizationConsent"] as? String == "granted")
  }

  @Test(arguments: [FakeTrackingAuthorizationStatus.notDetermined, .authorized])
  func attUndeterminedOrAuthorized_reportsTheChosenConsent(
    _ attStatus: FakeTrackingAuthorizationStatus
  ) async {
    let dependencyContainer = DependencyContainer(cache: CacheMock())
    let deviceHelper = makeDeviceHelper(dependencyContainer, attStatus: attStatus)
    let options = dependencyContainer.configManager.options

    options.adConsent = AdConsent(adUserData: .denied, adPersonalization: .granted)
    let granted = await deviceHelper.getTemplateDevice()
    #expect(granted["adUserDataConsent"] as? String == "denied")
    #expect(granted["adPersonalizationConsent"] as? String == "granted")

    options.adConsent = AdConsent(adUserData: .granted, adPersonalization: .denied)
    let denied = await deviceHelper.getTemplateDevice()
    #expect(denied["adUserDataConsent"] as? String == "granted")
    #expect(denied["adPersonalizationConsent"] as? String == "denied")
  }

  @Test func attDenied_withTrackingNone_deniesBoth() {
    let consent = AdConsent(adUserData: .granted, adPersonalization: .granted)

    let reported = consent.reported(
      for: .none,
      attStatus: FakeTrackingAuthorizationStatus.denied.rawValue
    )

    #expect(reported.adUserData == .denied)
    #expect(reported.adPersonalization == .denied)
  }

  @Test(arguments: [EventTrackingBehavior.all, .superwallOnly])
  func otherTrackingBehaviors_reportTheChosenConsent(_ behavior: EventTrackingBehavior) {
    let consent = AdConsent(adUserData: .denied, adPersonalization: .granted)

    let reported = consent.reported(for: behavior, attStatus: nil)

    #expect(reported.adUserData == .denied)
    #expect(reported.adPersonalization == .granted)
  }

  // MARK: - Runtime updates

  @Test func settingAdConsent_tracksConfigAndDeviceAttributes() async {
    let (superwall, _, recorder) = makeSuperwall(attStatus: ATTStatusBox(.authorized))

    superwall.adConsent = AdConsent(adUserData: .denied, adPersonalization: .denied)

    await waitUntil { !recorder.sent.isEmpty }
    #expect(recorder.sentConfigAttributes.count == 1)
    #expect(recorder.sentConfigAttributes.last?["adUserDataConsent"] as? String == "denied")
    #expect(
      recorder.sentConfigAttributes.last?["adPersonalizationConsent"] as? String == "denied"
    )
    #expect(recorder.sent.count == 1)
    #expect(recorder.sent.last?["adUserDataConsent"] as? String == "denied")
    #expect(recorder.sent.last?["adPersonalizationConsent"] as? String == "denied")
  }

  @Test func rapidAssignments_lastAssignmentWins() async {
    let (superwall, _, recorder) = makeSuperwall(attStatus: ATTStatusBox(.authorized))

    superwall.adConsent = AdConsent(adUserData: .granted, adPersonalization: .granted)
    superwall.adConsent = AdConsent(adUserData: .denied, adPersonalization: .denied)

    await waitUntil {
      recorder.sent.last?["adUserDataConsent"] as? String == "denied"
    }
    // Give a stale snapshot the chance to land late, if it were going to.
    try? await Task.sleep(nanoseconds: 300_000_000)
    #expect(recorder.sent.last?["adUserDataConsent"] as? String == "denied")
    #expect(recorder.sent.last?["adPersonalizationConsent"] as? String == "denied")
    #expect(
      recorder.sentConfigAttributes.last?["adUserDataConsent"] as? String == "denied"
    )
  }

  // MARK: - Republishing on ATT changes

  @Test func attChange_republishesDeviceAttributesOnce() async {
    let attStatus = ATTStatusBox(.notDetermined)
    let (superwall, dependencyContainer, recorder) = makeSuperwall(attStatus: attStatus)

    // The initial upload reports the option, since ATT hasn't been asked yet.
    let initial = await dependencyContainer.makeSessionDeviceAttributes()
    await superwall.track(InternalSuperwallEvent.DeviceAttributes(deviceAttributes: initial))
    #expect(recorder.sent.count == 1)
    #expect(recorder.sent.last?["adPersonalizationConsent"] as? String == "granted")

    // Unchanged: nothing to send.
    #expect(await superwall.republishDeviceAttributesIfAdConsentChanged() == false)
    #expect(recorder.sent.count == 1)

    // The user denies the ATT prompt mid-session.
    attStatus.value = .denied
    #expect(await superwall.republishDeviceAttributesIfAdConsentChanged() == true)
    #expect(recorder.sent.count == 2)
    #expect(recorder.sent.last?["adPersonalizationConsent"] as? String == "denied")
    #expect(recorder.sent.last?["adUserDataConsent"] as? String == "granted")

    // Already reflected: no second republish.
    #expect(await superwall.republishDeviceAttributesIfAdConsentChanged() == false)
    #expect(recorder.sent.count == 2)
  }

  @Test func attChangeWhileOptedOut_republishesOnceTrackingResumes() async {
    let attStatus = ATTStatusBox(.notDetermined)
    let (superwall, dependencyContainer, recorder) = makeSuperwall(attStatus: attStatus)

    // `.all` sends granted.
    let initial = await dependencyContainer.makeSessionDeviceAttributes()
    await superwall.track(InternalSuperwallEvent.DeviceAttributes(deviceAttributes: initial))
    #expect(recorder.sent.last?["adPersonalizationConsent"] as? String == "granted")

    // Opted out, the user denies tracking. Activation mustn't treat that as sent.
    superwall.eventTrackingBehavior = .none
    attStatus.value = .denied
    #expect(await superwall.republishDeviceAttributesIfAdConsentChanged() == false)
    // Even a device-attributes event tracked while opted out is dropped, not sent.
    let droppedAttributes = await dependencyContainer.makeSessionDeviceAttributes()
    await superwall.track(
      InternalSuperwallEvent.DeviceAttributes(deviceAttributes: droppedAttributes)
    )

    // Opting back in sends the denied value exactly once.
    let sentBeforeOptIn = recorder.sent.count
    superwall.eventTrackingBehavior = .all
    await waitUntil { recorder.sent.count > sentBeforeOptIn }
    try? await Task.sleep(nanoseconds: 300_000_000)
    #expect(recorder.sent.count == sentBeforeOptIn + 1)
    #expect(recorder.sent.last?["adPersonalizationConsent"] as? String == "denied")

    // Now it's sent, activation has nothing more to do.
    #expect(await superwall.republishDeviceAttributesIfAdConsentChanged() == false)
    #expect(recorder.sent.count == sentBeforeOptIn + 1)
  }

  @Test func attChange_beforeAnyUpload_doesNotRepublish() async {
    let attStatus = ATTStatusBox(.notDetermined)
    let (superwall, _, recorder) = makeSuperwall(attStatus: attStatus)

    attStatus.value = .denied

    // The first upload reports the current value, so there's nothing stale yet.
    #expect(await superwall.republishDeviceAttributesIfAdConsentChanged() == false)
    #expect(recorder.sent.isEmpty)
  }

  @Test func appActivation_republishesOnlyWhenATTChanged() async {
    let attStatus = ATTStatusBox(.notDetermined)
    let (superwall, dependencyContainer, recorder) = makeSuperwall(attStatus: attStatus)
    // `AppSessionManager` holds its delegate `unowned`.
    let sessionDelegate = AppManagerDelegateMock()
    let appSessionManager = AppSessionManager(
      configManager: dependencyContainer.configManager,
      identityManager: dependencyContainer.identityManager,
      storage: dependencyContainer.storage,
      delegate: sessionDelegate,
      republishIfAdConsentChanged: {
        await superwall.republishDeviceAttributesIfAdConsentChanged()
      }
    )
    // Let the manager register its observers.
    try? await Task.sleep(nanoseconds: 100_000_000)

    let initial = await dependencyContainer.makeSessionDeviceAttributes()
    await superwall.track(InternalSuperwallEvent.DeviceAttributes(deviceAttributes: initial))

    // Activation without an ATT change sends nothing.
    await NotificationCenter.default.post(
      Notification(name: UIApplication.didBecomeActiveNotification)
    )
    try? await Task.sleep(nanoseconds: 300_000_000)
    #expect(recorder.sent.count == 1)

    // Activation after the user denied tracking sends exactly one update.
    attStatus.value = .denied
    await NotificationCenter.default.post(
      Notification(name: UIApplication.didBecomeActiveNotification)
    )
    await waitUntil { recorder.sent.count >= 2 }
    try? await Task.sleep(nanoseconds: 300_000_000)
    #expect(recorder.sent.count == 2)
    #expect(recorder.sent.last?["adPersonalizationConsent"] as? String == "denied")
    withExtendedLifetime((appSessionManager, sessionDelegate, dependencyContainer)) {}
  }

  @Test(arguments: [
    (PermissionType.tracking, "denied", 2),
    (PermissionType.notification, "granted", 1)
  ])
  @MainActor
  func paywallPermissionRequest_republishesOnlyForTracking(
    permissionType: PermissionType,
    expectedPersonalization: String,
    expectedSends: Int
  ) async {
    let attStatus = ATTStatusBox(.notDetermined)
    let (superwall, dependencyContainer, recorder) = makeSuperwall(attStatus: attStatus)
    let initial = await dependencyContainer.makeSessionDeviceAttributes()
    await superwall.track(InternalSuperwallEvent.DeviceAttributes(deviceAttributes: initial))
    #expect(recorder.sent.count == 1)

    // The user denies tracking while the request is in flight. For a
    // non-tracking request, the hook mustn't run even though ATT changed.
    let permissions = FakePermissionHandler()
    permissions.permissionToReturn = .denied
    permissions.onRequest = { _ in attStatus.value = .denied }
    let messageHandler = PaywallMessageHandler(
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      permissionHandler: permissions,
      customCallbackRegistry: dependencyContainer.customCallbackRegistry,
      republishIfAdConsentChanged: {
        await superwall.republishDeviceAttributesIfAdConsentChanged()
      }
    )
    let webView = FakeWebView(
      isMac: false,
      messageHandler: messageHandler,
      isOnDeviceCacheEnabled: true,
      factory: dependencyContainer
    )
    let delegate = PaywallMessageHandlerDelegateMock(paywallInfo: .stub(), webView: webView)
    messageHandler.delegate = delegate

    messageHandler.handle(
      .requestPermission(permissionType: permissionType, requestId: "request")
    )

    // `permission_result` goes back to the web view after the republish hook.
    await waitUntil { webView.willHandleJs }
    #expect(webView.willHandleJs)
    #expect(recorder.sent.count == expectedSends)
    #expect(
      recorder.sent.last?["adPersonalizationConsent"] as? String == expectedPersonalization
    )
    withExtendedLifetime(delegate) {}
  }

  @Test func options_serializeAdConsentForConfigAttributes() {
    let options = SuperwallOptions()
    options.adConsent = AdConsent(adUserData: .denied, adPersonalization: .granted)

    let dictionary = options.toDictionary()

    #expect(dictionary["adUserDataConsent"] as? String == "denied")
    #expect(dictionary["adPersonalizationConsent"] as? String == "granted")
  }

  /// A helper whose ATT status is fixed, since the simulator's real status
  /// can't be set from a test. The container is held by the caller because the
  /// helper only keeps its factory `unowned`.
  private func makeDeviceHelper(
    _ dependencyContainer: DependencyContainer,
    attStatus: FakeTrackingAuthorizationStatus
  ) -> DeviceHelper {
    return DeviceHelper(
      api: dependencyContainer.api,
      storage: dependencyContainer.storage,
      network: dependencyContainer.network,
      entitlementsInfo: dependencyContainer.entitlementsInfo,
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      attStatusProvider: { attStatus.rawValue }
    )
  }

  /// A `Superwall` whose device helper reads `attStatus`, with a delegate that
  /// records every device-attributes event it sends.
  private func makeSuperwall(
    attStatus: ATTStatusBox
  ) -> (Superwall, DependencyContainer, MockSuperwallDelegate) {
    let dependencyContainer = DependencyContainer(cache: CacheMock())
    dependencyContainer.deviceHelper = DeviceHelper(
      api: dependencyContainer.api,
      storage: dependencyContainer.storage,
      network: dependencyContainer.network,
      entitlementsInfo: dependencyContainer.entitlementsInfo,
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      attStatusProvider: { attStatus.value.rawValue }
    )
    let superwall = Superwall(dependencyContainer: dependencyContainer)
    let recorder = MockSuperwallDelegate()
    dependencyContainer.delegateAdapter.swiftDelegate = recorder
    return (superwall, dependencyContainer, recorder)
  }

  private func waitUntil(
    timeout: TimeInterval = 2,
    _ condition: @escaping () -> Bool
  ) async {
    let start = Date()
    while !condition() && Date().timeIntervalSince(start) < timeout {
      try? await Task.sleep(nanoseconds: 50_000_000)
    }
  }
}

private final class ATTStatusBox: @unchecked Sendable {
  private let lock = NSLock()
  private var _value: FakeTrackingAuthorizationStatus

  init(_ value: FakeTrackingAuthorizationStatus) {
    _value = value
  }

  var value: FakeTrackingAuthorizationStatus {
    get { lock.withLock { _value } }
    set { lock.withLock { _value = newValue } }
  }
}

extension MockSuperwallDelegate {
  /// The attributes of every `device_attributes` event, in the order they were tracked.
  var sent: [[String: Any]] {
    eventsReceived.compactMap { event in
      if case let .deviceAttributes(attributes) = event {
        return attributes
      }
      return nil
    }
  }

  /// The parameters of every `config_attributes` event, in the order they were tracked.
  var sentConfigAttributes: [[String: Any]] {
    eventInfosReceived.compactMap { info in
      if case .configAttributes = info.event {
        return info.params
      }
      return nil
    }
  }
}
