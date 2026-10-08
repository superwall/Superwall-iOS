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

  @Test func consentStatus_descriptionsMatchTheServerContract() {
    #expect(ConsentStatus.granted.description == "granted")
    #expect(ConsentStatus.denied.description == "denied")
  }

  @Test func templateDevice_reportsGrantedByDefault() async {
    let dependencyContainer = DependencyContainer(cache: CacheMock())

    let template = await dependencyContainer.deviceHelper.getTemplateDevice()

    #expect(template["adUserDataConsent"] as? String == "granted")
    #expect(template["adPersonalizationConsent"] as? String == "granted")
  }

  @Test func settingAdConsentAtRuntime_isReflectedInDeviceAttributes() async {
    let dependencyContainer = DependencyContainer(cache: CacheMock())
    let superwall = Superwall(dependencyContainer: dependencyContainer)

    superwall.adConsent = AdConsent(adUserData: .denied, adPersonalization: .granted)

    #expect(dependencyContainer.configManager.options.adConsent.adUserData == .denied)
    let template = await dependencyContainer.deviceHelper.getTemplateDevice()
    #expect(template["adUserDataConsent"] as? String == "denied")
    #expect(template["adPersonalizationConsent"] as? String == "granted")

    superwall.adConsent = AdConsent(adUserData: .granted, adPersonalization: .denied)

    let updated = await dependencyContainer.makeSessionDeviceAttributes()
    #expect(updated["adUserDataConsent"] as? String == "granted")
    #expect(updated["adPersonalizationConsent"] as? String == "denied")
  }

  @Test func eventTrackingBehaviorNone_reportsDenied() async {
    let dependencyContainer = DependencyContainer(cache: CacheMock())
    let options = dependencyContainer.configManager.options
    options.adConsent = AdConsent(adUserData: .granted, adPersonalization: .granted)
    options.eventTrackingBehavior = .none

    let template = await dependencyContainer.deviceHelper.getTemplateDevice()

    #expect(template["adUserDataConsent"] as? String == "denied")
    #expect(template["adPersonalizationConsent"] as? String == "denied")
    // The developer's choice itself is left untouched.
    #expect(options.adConsent.adUserData == .granted)
    #expect(options.adConsent.adPersonalization == .granted)
  }

  @Test(arguments: [EventTrackingBehavior.all, .superwallOnly])
  func otherTrackingBehaviors_reportTheChosenConsent(_ behavior: EventTrackingBehavior) {
    let consent = AdConsent(adUserData: .denied, adPersonalization: .granted)

    let reported = consent.reported(for: behavior)

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
}
