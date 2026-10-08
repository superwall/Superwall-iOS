//
//  AdConsentTests.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 08/10/2026.
//

@testable import SuperwallKit
import Testing
import Foundation

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
}
