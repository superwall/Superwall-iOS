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
    await drainAdConsentUpdates(superwall)
    withExtendedLifetime(dependencyContainer) {}
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
    withExtendedLifetime(dependencyContainer) {}
  }

  @Test(arguments: [FakeTrackingAuthorizationStatus.denied, .restricted])
  func attNotAllowed_deniesDefaultPersonalizationOnly(
    _ attStatus: FakeTrackingAuthorizationStatus
  ) async {
    let dependencyContainer = DependencyContainer(cache: CacheMock())
    let deviceHelper = makeDeviceHelper(dependencyContainer, attStatus: attStatus)
    let options = dependencyContainer.configManager.options

    let template = await deviceHelper.getTemplateDevice()

    #expect(template["adUserDataConsent"] as? String == "granted")
    #expect(template["adPersonalizationConsent"] as? String == "denied")
    #expect(template["adConsentSource"] as? String == "default")
    // The stored option, which `config_attributes` reports, is left untouched.
    #expect(options.adConsent.adPersonalization == .granted)
    #expect(options.toDictionary()["adPersonalizationConsent"] as? String == "granted")
    withExtendedLifetime(dependencyContainer) {}
  }

  @Test(arguments: [FakeTrackingAuthorizationStatus.denied, .restricted])
  func attNotAllowed_leavesTheAppsOwnConsentAlone(
    _ attStatus: FakeTrackingAuthorizationStatus
  ) async {
    let dependencyContainer = DependencyContainer(cache: CacheMock())
    let deviceHelper = makeDeviceHelper(dependencyContainer, attStatus: attStatus)
    dependencyContainer.configManager.options.adConsent = AdConsent(
      adUserData: .granted,
      adPersonalization: .granted
    )

    let template = await deviceHelper.getTemplateDevice()

    #expect(template["adUserDataConsent"] as? String == "granted")
    #expect(template["adPersonalizationConsent"] as? String == "granted")
    #expect(template["adConsentSource"] as? String == "developer")
    withExtendedLifetime(dependencyContainer) {}
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
    withExtendedLifetime(dependencyContainer) {}
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

  // MARK: - Consent banners (IAB TCF)

  @Test(arguments: [
    ("1111111111", AdConsentStatus.granted, AdConsentStatus.granted),
    ("1101111111", .granted, .denied),
    ("0111111111", .denied, .granted),
    ("0000000000", .denied, .denied)
  ])
  func tcf_mapsPurposesToConsent(
    purposes: String,
    adUserData: AdConsentStatus,
    adPersonalization: AdConsentStatus
  ) {
    let banner = BannerDefaults(gdprApplies: 1, purposes: purposes)

    let consent = TCFConsent.consent(from: banner.defaults)

    #expect(consent?.adUserData == adUserData)
    #expect(consent?.adPersonalization == adPersonalization)
  }

  @Test func tcf_shortStringCountsMissingPurposesAsNotAgreed() {
    // Purposes 1 to 4 only: 7 is missing, so ad user data is denied.
    let banner = BannerDefaults(gdprApplies: 1, purposes: "1111")

    let consent = TCFConsent.consent(from: banner.defaults)

    #expect(consent?.adUserData == .denied)
    #expect(consent?.adPersonalization == .granted)
  }

  @Test(arguments: [
    BannerFixture(gdprApplies: 0, purposes: "1111111111"),
    BannerFixture(gdprApplies: nil, purposes: "1111111111"),
    BannerFixture(gdprApplies: 1, purposes: ""),
    BannerFixture(gdprApplies: 1, purposes: nil)
  ])
  func tcf_withoutEURulesOrAnAnswer_fallsBackToDefault(_ fixture: BannerFixture) async {
    let banner = BannerDefaults(gdprApplies: fixture.gdprApplies, purposes: fixture.purposes)
    #expect(TCFConsent.consent(from: banner.defaults) == nil)

    let dependencyContainer = DependencyContainer(cache: CacheMock())
    let deviceHelper = makeDeviceHelper(dependencyContainer, attStatus: .authorized, banner: banner)
    let template = await deviceHelper.getTemplateDevice()

    #expect(template["adUserDataConsent"] as? String == "granted")
    #expect(template["adPersonalizationConsent"] as? String == "granted")
    #expect(template["adConsentSource"] as? String == "default")
    withExtendedLifetime(dependencyContainer) {}
  }

  @Test func tcf_isReportedWhenTheAppHasNotSetConsent() async {
    let banner = BannerDefaults(gdprApplies: 1, purposes: "0000000000")
    let dependencyContainer = DependencyContainer(cache: CacheMock())
    let deviceHelper = makeDeviceHelper(dependencyContainer, attStatus: .authorized, banner: banner)

    let template = await deviceHelper.getTemplateDevice()

    #expect(template["adUserDataConsent"] as? String == "denied")
    #expect(template["adPersonalizationConsent"] as? String == "denied")
    #expect(template["adConsentSource"] as? String == "tcf")
    // The stored option, which `config_attributes` reports, isn't touched.
    let options = dependencyContainer.configManager.options
    #expect(options.toDictionary()["adUserDataConsent"] as? String == "granted")
    #expect(options.toDictionary()["isAdConsentSet"] as? Bool == false)
    withExtendedLifetime(dependencyContainer) {}
  }

  @Test func developerConsent_winsOverTheBanner_evenWhenSetToTheDefault() async {
    let banner = BannerDefaults(gdprApplies: 1, purposes: "0000000000")
    let dependencyContainer = DependencyContainer(cache: CacheMock())
    let deviceHelper = makeDeviceHelper(dependencyContainer, attStatus: .authorized, banner: banner)

    // Set through the options, as at configure.
    let options = dependencyContainer.configManager.options
    options.adConsent = AdConsent()
    let template = await deviceHelper.getTemplateDevice()
    #expect(template["adUserDataConsent"] as? String == "granted")
    #expect(template["adPersonalizationConsent"] as? String == "granted")
    #expect(template["adConsentSource"] as? String == "developer")
    #expect(options.toDictionary()["isAdConsentSet"] as? Bool == true)
    withExtendedLifetime(dependencyContainer) {}
  }

  @Test func developerConsentSetAtRuntime_winsOverTheBanner() async {
    let banner = BannerDefaults(gdprApplies: 1, purposes: "0000000000")
    let (superwall, dependencyContainer, _) = makeSuperwall(
      attStatus: ATTStatusBox(.authorized),
      banner: banner
    )
    #expect(dependencyContainer.deviceHelper.reportedAdConsent.source == "tcf")

    superwall.adConsent = AdConsent()

    let reported = dependencyContainer.deviceHelper.reportedAdConsent
    #expect(reported == ReportedAdConsent(
      adUserData: "granted",
      adPersonalization: "granted",
      source: "developer"
    ))
    await drainAdConsentUpdates(superwall)
  }

  @Test func tcf_attStillDeniesPersonalization() async {
    let banner = BannerDefaults(gdprApplies: 1, purposes: "1111111111")
    let dependencyContainer = DependencyContainer(cache: CacheMock())
    let deviceHelper = makeDeviceHelper(dependencyContainer, attStatus: .denied, banner: banner)

    #expect(deviceHelper.reportedAdConsent == ReportedAdConsent(
      adUserData: "granted",
      adPersonalization: "denied",
      source: "tcf"
    ))
    withExtendedLifetime(dependencyContainer) {}
  }

  @Test func trackingNone_deniesBothOverTheBanner() async {
    let banner = BannerDefaults(gdprApplies: 1, purposes: "1111111111")
    let dependencyContainer = DependencyContainer(cache: CacheMock())
    let deviceHelper = makeDeviceHelper(dependencyContainer, attStatus: .authorized, banner: banner)
    dependencyContainer.configManager.options.eventTrackingBehavior = .none

    #expect(deviceHelper.reportedAdConsent == ReportedAdConsent(
      adUserData: "denied",
      adPersonalization: "denied",
      source: "tcf"
    ))
    withExtendedLifetime(dependencyContainer) {}
  }

  @Test func bannerChange_republishesOnceWithTheNewConsent() async {
    let banner = BannerDefaults()
    let (superwall, dependencyContainer, recorder) = makeSuperwall(
      attStatus: ATTStatusBox(.authorized),
      banner: banner
    )
    let notificationCenter = NotificationCenter()
    let observer = TCFConsentObserver(
      defaults: banner.defaults,
      notificationCenter: notificationCenter,
      onChange: { await superwall.republishDeviceAttributesIfAdConsentChanged() }
    )
    let initial = await dependencyContainer.makeSessionDeviceAttributes()
    await superwall.track(InternalSuperwallEvent.DeviceAttributes(deviceAttributes: initial))
    // Let the reconcile that follows every send settle before the test changes anything.
    await drainAdConsentUpdates(superwall)
    #expect(recorder.sent.last?["adConsentSource"] as? String == "default")

    // An unrelated defaults write sends nothing.
    banner.defaults.set("value", forKey: "unrelated")
    notificationCenter.post(name: UserDefaults.didChangeNotification, object: banner.defaults)
    try? await Task.sleep(nanoseconds: 300_000_000)
    await drainAdConsentUpdates(superwall)
    #expect(recorder.sent.count == 1)

    // The user answers the banner, denying personalization.
    banner.set(gdprApplies: 1, purposes: "1101111111")
    notificationCenter.post(name: UserDefaults.didChangeNotification, object: banner.defaults)
    await waitUntil { recorder.sent.count > 1 }
    try? await Task.sleep(nanoseconds: 300_000_000)
    await drainAdConsentUpdates(superwall)
    #expect(recorder.sent.count == 2)
    #expect(recorder.sent.last?["adUserDataConsent"] as? String == "granted")
    #expect(recorder.sent.last?["adPersonalizationConsent"] as? String == "denied")
    #expect(recorder.sent.last?["adConsentSource"] as? String == "tcf")

    // The same answer again sends nothing.
    notificationCenter.post(name: UserDefaults.didChangeNotification, object: banner.defaults)
    try? await Task.sleep(nanoseconds: 300_000_000)
    await drainAdConsentUpdates(superwall)
    #expect(recorder.sent.count == 2)
    withExtendedLifetime(observer) {}
  }

  @Test(arguments: [true, false])
  func bannerChangeDuringTheFirstUpload_isSentOnceItFinishes(bannerChanges: Bool) async {
    let banner = BannerDefaults()
    let (superwall, dependencyContainer, recorder) = makeSuperwall(
      attStatus: ATTStatusBox(.authorized),
      banner: banner
    )
    let notificationCenter = NotificationCenter()
    let observer = TCFConsentObserver(
      defaults: banner.defaults,
      notificationCenter: notificationCenter,
      onChange: { await superwall.republishDeviceAttributesIfAdConsentChanged() }
    )
    // Hold the first build after it has read the (default) consent.
    let gate = SnapshotGate()
    dependencyContainer.deviceHelper.afterAdConsentSnapshot = { await gate.pass() }

    let firstUpload = Task {
      let attributes = await dependencyContainer.makeSessionDeviceAttributes()
      await superwall.track(InternalSuperwallEvent.DeviceAttributes(deviceAttributes: attributes))
    }
    await gate.waitUntilEntered()

    if bannerChanges {
      // Nothing has been sent yet, so this alone can't republish anything.
      banner.set(gdprApplies: 1, purposes: "0000000000")
      notificationCenter.post(name: UserDefaults.didChangeNotification, object: banner.defaults)
      try? await Task.sleep(nanoseconds: 200_000_000)
      #expect(recorder.sent.isEmpty)
    }

    await gate.release()
    await firstUpload.value
    try? await Task.sleep(nanoseconds: 300_000_000)
    await drainAdConsentUpdates(superwall)

    #expect(recorder.sent.first?["adConsentSource"] as? String == "default")
    if bannerChanges {
      #expect(recorder.sent.count == 2)
      #expect(recorder.sent.last?["adUserDataConsent"] as? String == "denied")
      #expect(recorder.sent.last?["adPersonalizationConsent"] as? String == "denied")
      #expect(recorder.sent.last?["adConsentSource"] as? String == "tcf")
    } else {
      #expect(recorder.sent.count == 1)
    }
    withExtendedLifetime(observer) {}
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
    await drainAdConsentUpdates(superwall)
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
    await drainAdConsentUpdates(superwall)
  }

  // MARK: - Republishing on ATT changes

  @Test func attChange_republishesDeviceAttributesOnce() async {
    let attStatus = ATTStatusBox(.notDetermined)
    let (superwall, dependencyContainer, recorder) = makeSuperwall(attStatus: attStatus)

    // The initial upload reports the option, since ATT hasn't been asked yet.
    let initial = await dependencyContainer.makeSessionDeviceAttributes()
    await superwall.track(InternalSuperwallEvent.DeviceAttributes(deviceAttributes: initial))
    // Let the reconcile that follows every send settle before the test changes anything.
    await drainAdConsentUpdates(superwall)
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
    await drainAdConsentUpdates(superwall)
    withExtendedLifetime(dependencyContainer) {}
  }

  @Test func attChangeWhileOptedOut_republishesOnceTrackingResumes() async {
    let attStatus = ATTStatusBox(.notDetermined)
    let (superwall, dependencyContainer, recorder) = makeSuperwall(attStatus: attStatus)

    // `.all` sends granted.
    let initial = await dependencyContainer.makeSessionDeviceAttributes()
    await superwall.track(InternalSuperwallEvent.DeviceAttributes(deviceAttributes: initial))
    // Let the reconcile that follows every send settle before the test changes anything.
    await drainAdConsentUpdates(superwall)
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
    await drainAdConsentUpdates(superwall)
    withExtendedLifetime(dependencyContainer) {}
  }

  @Test func adConsentSetWhileOptedOut_isSentOnceTrackingResumes() async {
    let (superwall, dependencyContainer, recorder) = makeSuperwall(
      attStatus: ATTStatusBox(.authorized)
    )

    // Both granted are sent.
    let initial = await dependencyContainer.makeSessionDeviceAttributes()
    await superwall.track(InternalSuperwallEvent.DeviceAttributes(deviceAttributes: initial))
    // Let the reconcile that follows every send settle before the test changes anything.
    await drainAdConsentUpdates(superwall)
    #expect(recorder.sent.last?["adUserDataConsent"] as? String == "granted")

    // Opted out, only ad user data is denied. That doesn't change personalization,
    // and what the setter tracks is dropped.
    superwall.eventTrackingBehavior = .none
    let sentBeforeAssignment = recorder.sent.count
    superwall.adConsent = AdConsent(adUserData: .denied)
    await waitUntil { recorder.sent.count > sentBeforeAssignment }

    // Opting back in always re-sends the device attributes, exactly once.
    let sentBeforeOptIn = recorder.sent.count
    superwall.eventTrackingBehavior = .all
    await waitUntil { recorder.sent.count > sentBeforeOptIn }
    try? await Task.sleep(nanoseconds: 300_000_000)
    #expect(recorder.sent.count == sentBeforeOptIn + 1)
    #expect(recorder.sent.last?["adUserDataConsent"] as? String == "denied")
    #expect(recorder.sent.last?["adPersonalizationConsent"] as? String == "granted")
    await drainAdConsentUpdates(superwall)
    withExtendedLifetime(dependencyContainer) {}
  }

  @Test func switchingToSuperwallOnly_resendsDiscardedDeviceAttributes() async {
    let attStatus = ATTStatusBox(.notDetermined)
    let (superwall, dependencyContainer, recorder) = makeSuperwall(attStatus: attStatus)
    let queue = dependencyContainer.placementsQueue!

    // Granted is sent, then the ATT denial is queued and recorded as sent.
    let initial = await dependencyContainer.makeSessionDeviceAttributes()
    await superwall.track(InternalSuperwallEvent.DeviceAttributes(deviceAttributes: initial))
    // Let the reconcile that follows every send settle before the test changes anything.
    await drainAdConsentUpdates(superwall)
    attStatus.value = .denied
    #expect(await superwall.republishDeviceAttributesIfAdConsentChanged() == true)
    #expect(await queue.queuedEventNames.contains("device_attributes"))

    // Before a flush, `.superwallOnly` discards everything queued, the denial too.
    let sentBeforeSwitch = recorder.sent.count
    superwall.eventTrackingBehavior = .superwallOnly
    await waitUntil { recorder.sent.count > sentBeforeSwitch }
    await drainAdConsentUpdates(superwall)

    // A fresh copy went out after the switch, and the queue kept it.
    #expect(recorder.sent.count == sentBeforeSwitch + 1)
    #expect(recorder.sent.last?["adPersonalizationConsent"] as? String == "denied")
    #expect(await queue.queuedEventNames.filter { $0 == "device_attributes" }.count == 1)
    withExtendedLifetime(dependencyContainer) {}
  }

  @Test func attChange_beforeAnyUpload_doesNotRepublish() async {
    let attStatus = ATTStatusBox(.notDetermined)
    let (superwall, _, recorder) = makeSuperwall(attStatus: attStatus)

    attStatus.value = .denied

    // The first upload reports the current value, so there's nothing stale yet.
    #expect(await superwall.republishDeviceAttributesIfAdConsentChanged() == false)
    #expect(recorder.sent.isEmpty)
    await drainAdConsentUpdates(superwall)
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
      },
      // Not `.default`, so app-wide lifecycle notifications posted by other suites
      // can't start handlers that outlive this test.
      notificationCenter: NotificationCenter()
    )
    let initial = await dependencyContainer.makeSessionDeviceAttributes()
    await superwall.track(InternalSuperwallEvent.DeviceAttributes(deviceAttributes: initial))
    // Let the reconcile that follows every send settle before the test changes anything.
    await drainAdConsentUpdates(superwall)

    // Activation without an ATT change sends nothing. The handler is awaited
    // directly rather than posting the app-wide notification, which would also
    // wake managers from suites running in parallel.
    await appSessionManager.didBecomeActive()
    #expect(recorder.sent.count == 1)

    // Activation after the user denied tracking sends exactly one update.
    attStatus.value = .denied
    await appSessionManager.didBecomeActive()
    #expect(recorder.sent.count == 2)
    #expect(recorder.sent.last?["adPersonalizationConsent"] as? String == "denied")
    withExtendedLifetime((appSessionManager, sessionDelegate, dependencyContainer)) {}
    await drainAdConsentUpdates(superwall)
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
    // Let the reconcile that follows every send settle before the test changes anything.
    await drainAdConsentUpdates(superwall)
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
    await drainAdConsentUpdates(superwall)
    withExtendedLifetime(dependencyContainer) {}
  }

  @Test func options_serializeAdConsentForConfigAttributes() {
    let options = SuperwallOptions()
    options.adConsent = AdConsent(adUserData: .denied, adPersonalization: .granted)

    let dictionary = options.toDictionary()

    #expect(dictionary["adUserDataConsent"] as? String == "denied")
    #expect(dictionary["adPersonalizationConsent"] as? String == "granted")
  }

  /// The container's own device helper with its ATT status set for the test. The
  /// caller keeps the container alive, since the helper holds it `unowned`.
  ///
  /// It reads banner consent from `banner`, or from an empty suite, so nothing in
  /// the test host's standard defaults can leak in.
  private func makeDeviceHelper(
    _ dependencyContainer: DependencyContainer,
    attStatus: FakeTrackingAuthorizationStatus,
    banner: BannerDefaults = BannerDefaults()
  ) -> DeviceHelper {
    let deviceHelper: DeviceHelper = dependencyContainer.deviceHelper
    deviceHelper.attStatusProvider = { attStatus.rawValue }
    deviceHelper.consentDefaults = banner.defaults
    return deviceHelper
  }

  /// A `Superwall` whose device helper reads `attStatus`, with a delegate that
  /// records every device-attributes event it sends.
  private func makeSuperwall(
    attStatus: ATTStatusBox,
    banner: BannerDefaults = BannerDefaults()
  ) -> (Superwall, DependencyContainer, MockSuperwallDelegate) {
    let dependencyContainer = DependencyContainer(cache: CacheMock())
    dependencyContainer.deviceHelper.attStatusProvider = { attStatus.value.rawValue }
    dependencyContainer.deviceHelper.consentDefaults = banner.defaults
    let superwall = Superwall(dependencyContainer: dependencyContainer)
    let recorder = MockSuperwallDelegate()
    dependencyContainer.delegateAdapter.swiftDelegate = recorder
    return (superwall, dependencyContainer, recorder)
  }

  /// Waits for the ad consent work the test started, so it finishes inside the
  /// test. Bounded, so a StoreKit or Core Data call that stalls on a loaded
  /// simulator fails the test's own expectations instead of hanging the run.
  private func drainAdConsentUpdates(_ superwall: Superwall) async {
    let drained = DrainedFlag()
    Task {
      await superwall.waitForPendingAdConsentUpdates()
      drained.set()
    }
    await waitUntil(timeout: 5) { drained.isSet }
    #expect(drained.isSet, "Ad consent updates didn't finish")
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

struct BannerFixture: Sendable, CustomTestStringConvertible {
  let gdprApplies: Int?
  let purposes: String?

  var testDescription: String {
    "gdprApplies \(gdprApplies.map(String.init) ?? "missing"), purposes \(purposes.map { "\"\($0)\"" } ?? "missing")"
  }
}

/// A private `UserDefaults` suite standing in for what a consent banner stores,
/// removed when the test is done with it.
final class BannerDefaults: @unchecked Sendable {
  let defaults: UserDefaults
  private let suiteName = "AdConsentTests.\(UUID().uuidString)"

  init(gdprApplies: Int? = nil, purposes: String? = nil) {
    defaults = UserDefaults(suiteName: suiteName)!
    set(gdprApplies: gdprApplies, purposes: purposes)
  }

  func set(gdprApplies: Int?, purposes: String?) {
    defaults.set(gdprApplies, forKey: TCFConsent.gdprAppliesKey)
    defaults.set(purposes, forKey: TCFConsent.purposeConsentsKey)
  }

  deinit {
    defaults.removePersistentDomain(forName: suiteName)
  }
}

/// Holds the first device attributes build until released; later builds pass.
private actor SnapshotGate {
  private var isEntered = false
  private var isReleased = false
  private var waiters: [CheckedContinuation<Void, Never>] = []

  func pass() async {
    if isReleased {
      return
    }
    isEntered = true
    await withCheckedContinuation { waiters.append($0) }
  }

  func waitUntilEntered() async {
    let start = Date()
    while !isEntered && Date().timeIntervalSince(start) < 5 {
      try? await Task.sleep(nanoseconds: 10_000_000)
    }
  }

  func release() {
    isReleased = true
    waiters.forEach { $0.resume() }
    waiters.removeAll()
  }
}

private final class DrainedFlag: @unchecked Sendable {
  private let lock = NSLock()
  private var _isSet = false

  var isSet: Bool {
    lock.withLock { _isSet }
  }

  func set() {
    lock.withLock { _isSet = true }
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
