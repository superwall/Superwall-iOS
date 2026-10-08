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
    #expect(ConsentStatus.granted.description == "granted")
    #expect(ConsentStatus.denied.description == "denied")
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
  ) -> (Superwall, DependencyContainer, DeviceAttributesRecorder) {
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
    let recorder = DeviceAttributesRecorder()
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

private final class DeviceAttributesRecorder: SuperwallDelegate, @unchecked Sendable {
  private let lock = NSLock()
  private var _sent: [[String: Any]] = []

  var sent: [[String: Any]] {
    lock.withLock { _sent }
  }

  func handleSuperwallEvent(withInfo eventInfo: SuperwallEventInfo) {
    if case let .deviceAttributes(attributes) = eventInfo.event {
      lock.withLock { _sent.append(attributes) }
    }
  }
}
