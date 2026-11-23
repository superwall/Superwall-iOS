//
//  SDKEnvironmentTests.swift
//  SuperwallKit
//
//  Created by Jake Mor on 23/10/2026.
//

import Foundation
import Testing
import UIKit
@testable import SuperwallKit

struct SDKEnvironmentTests {
  // MARK: - Embedded bundles

  @Test func embeddedFrameworks_dropAppleSuperwallAndOtherFiles() throws {
    let directory = try makeDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    try makeBundle(
      "AppsFlyerLib.framework",
      in: directory,
      info: ["CFBundleIdentifier": "com.appsflyer.sdk.lib", "CFBundleShortVersionString": "6.15.0"]
    )
    // Xcode copies these into a test host's Frameworks folder.
    try makeBundle(
      "XCTest.framework",
      in: directory,
      info: ["CFBundleIdentifier": "com.apple.dt.XCTest", "CFBundleShortVersionString": "16.0"]
    )
    try makeBundle("SuperwallKit.framework", in: directory, info: [:])
    try makeBundle("Firestore.framework", in: directory, info: nil)
    try makeBundle("Mixpanel_Mixpanel.bundle", in: directory, info: [:])
    try Data().write(to: directory.appendingPathComponent("libXCTestSwiftSupport.dylib"))
    try Data().write(to: directory.appendingPathComponent("libswift_Concurrency.dylib"))

    let frameworks = SDKEnvironmentLogic.embeddedBundles(in: directory, withExtension: "framework")

    #expect(frameworks == [
      .init(name: "AppsFlyerLib", bundleId: "com.appsflyer.sdk.lib", version: "6.15.0"),
      .init(name: "Firestore", bundleId: nil, version: nil)
    ])
  }

  @Test func resourceBundles_areListedWithoutSuperwallKits() throws {
    let directory = try makeDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    try makeBundle(
      "Mixpanel_Mixpanel.bundle",
      in: directory,
      info: ["CFBundleIdentifier": "mixpanel-swift.Mixpanel.resources"]
    )
    try makeBundle("SuperwallKit_SuperwallKit.bundle", in: directory, info: [:])
    try makeBundle("SuperwallKit.bundle", in: directory, info: [:])
    try makeBundle("AppsFlyerLib.framework", in: directory, info: [:])

    let bundles = SDKEnvironmentLogic.embeddedBundles(in: directory, withExtension: "bundle")

    #expect(bundles == [
      .init(name: "Mixpanel_Mixpanel", bundleId: "mixpanel-swift.Mixpanel.resources", version: nil)
    ])
  }

  @Test func embeddedBundles_missingDirectory_isEmpty() {
    let missing = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
    #expect(SDKEnvironmentLogic.embeddedBundles(in: missing, withExtension: "framework").isEmpty)
    #expect(SDKEnvironmentLogic.embeddedBundles(in: nil, withExtension: "framework").isEmpty)
  }

  @Test func embeddedBundles_areCappedAndTruncated() throws {
    let directory = try makeDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    for index in 0..<120 {
      try makeBundle("SDK\(index).framework", in: directory, info: [:])
    }
    let longVersion = String(repeating: "9", count: 300)
    try makeBundle(
      "\(String(repeating: "A", count: 150)).framework",
      in: directory,
      info: ["CFBundleShortVersionString": longVersion]
    )

    let info = SDKEnvironmentLogic.collect(from: sources(frameworks: directory))

    #expect(info.frameworkCount == 121)
    #expect(info.frameworks.count == SDKEnvironmentLogic.maxBundleCount)
    let long = try #require(info.frameworks.first)
    // Names are hashed whole; only the plain version is cut short.
    #expect(long.name == String(repeating: "A", count: 150))
    #expect(long.version?.count == SDKEnvironmentLogic.maxStringLength)
    // Byte order, which doesn't depend on the user's language.
    #expect(info.frameworks[1].name == "SDK0")
    #expect(info.frameworks[3].name == "SDK10")
  }

  @Test func liveSources_leaveOutApplesFrameworks() {
    // Xcode injects XCTest and its support frameworks into the test runner.
    let info = SDKEnvironmentLogic.collect(from: .live)
    let resourceBundles = SDKEnvironmentLogic.embeddedBundles(
      in: SDKEnvironmentSources.live.resourcesDirectory,
      withExtension: "bundle"
    )
    let bundleIds = (info.frameworks + resourceBundles).compactMap(\.bundleId)
    #expect(!bundleIds.contains { $0.hasPrefix("com.apple.") })
  }

  // MARK: - Linked code

  @Test func linkedCode_leavesOutTheMainModule() throws {
    let moduleClasses = (0..<250).map { "Module\($0).Thing" }
    let info = SDKEnvironmentLogic.collect(
      from: sources(
        info: ["CFBundleExecutable": "Tapes Dev"],
        classNames: ["Tapes_Dev.AppDelegate"] + moduleClasses
      )
    )

    let hashes = try decodedHashes(info.swiftModules.encoded)
    #expect(info.swiftModules.count == 250)
    #expect(hashes.count == 250)
    #expect(!hashes.contains(SDKEnvironmentLogic.nameHash("Tapes_Dev")))
    #expect(hashes.contains(SDKEnvironmentLogic.nameHash("Module7")))
  }

  // MARK: - Name hashes

  // Superwall's catalog of known SDKs hashes names the same way. If these change,
  // nothing the app sends matches it any more.
  @Test(arguments: [
    ("RCPurchases", "ed20ac30e55d7838", "7SCsMOVdeDg="),
    ("Mixpanel", "c683065e561d601a", "xoMGXlYdYBo=")
  ])
  func nameHash_matchesKnownVectors(name: String, hex: String, base64: String) {
    let hash = SDKEnvironmentLogic.nameHash(name)

    #expect(hash.map { String(format: "%02x", $0) }.joined() == hex)
    #expect(SDKEnvironmentLogic.encodedNameHash(name) == base64)
    #expect(SDKEnvironmentInfo.NameHashes.encoding == "sha256-64+base64")
  }

  @Test func nameHashes_areDeduplicatedSortedAndConcatenated() throws {
    let encoded = SDKEnvironmentLogic.nameHashes(["RCPurchases", "Mixpanel", "RCPurchases"])

    // `c683…` sorts before `ed20…`.
    let expected = SDKEnvironmentLogic.nameHash("Mixpanel") + SDKEnvironmentLogic.nameHash("RCPurchases")
    #expect(encoded.encoded == Data(expected).base64EncodedString())
    #expect(encoded.count == 2)
    #expect(!encoded.isTruncated)
  }

  @Test func nameHashes_doNotDependOnOrder() throws {
    let names = (0..<500).map { "SDK\($0 % 37)Class\($0)" }

    let first = SDKEnvironmentLogic.nameHashes(names)
    let second = SDKEnvironmentLogic.nameHashes(names.shuffled() + names.prefix(10))

    #expect(first == second)
    let hashes = try decodedHashes(first.encoded)
    #expect(hashes.count == 500)
    #expect(hashes == hashes.sorted { $0.lexicographicallyPrecedes($1) })
  }

  @Test func nameHashes_overTheCap_keepTheHashesThatSortFirst() throws {
    let names = (0..<200).map { "Vendor\($0)Thing" }

    // Room for 3 hashes: 24 bytes, 32 characters of base64.
    let encoded = SDKEnvironmentLogic.nameHashes(names, maxEncodedLength: 32)

    let allHashes = try decodedHashes(SDKEnvironmentLogic.nameHashes(names).encoded)
    #expect(try decodedHashes(encoded.encoded) == Array(allHashes.prefix(3)))
    #expect(encoded.encoded.count <= 32)
    #expect(encoded.isTruncated)
    #expect(encoded.count == 200)
    #expect(SDKEnvironmentLogic.maxEncodedNameHashesLength == 256 * 1024)
  }

  @Test func nameHashes_shareOneLimitAcrossTheEvent() {
    let maxHashCount = SDKEnvironmentLogic.maxEncodedNameHashesLength / 4 * 3 / SDKEnvironmentLogic.nameHashLength
    let scan = SDKEnvironmentScan.stub(
      swiftModules: (0..<1_000).map { "Module\($0)" },
      objcClassNames: (0..<maxHashCount).map { "SDKClass\($0)" }
    )

    let info = scan.info()

    let lists = [info.swiftModules, info.resourceBundles, info.objcClassNames]
    #expect(lists.map(\.encoded.count).reduce(0, +) <= SDKEnvironmentLogic.maxEncodedNameHashesLength)
    #expect(!info.swiftModules.isTruncated)
    #expect(!info.resourceBundles.isTruncated)
    #expect(info.objcClassNames.isTruncated)
    #expect(info.objcClassNames.count == maxHashCount)
  }

  @Test func nameHashes_whenThereAreNone() {
    let encoded = SDKEnvironmentLogic.nameHashes([])

    #expect(encoded.encoded.isEmpty)
    #expect(!encoded.isTruncated)
    #expect(encoded.count == 0)
  }

  @Test func encodedEvent_containsNoRawNames() async throws {
    let frameworksDirectory = try makeDirectory()
    let resourcesDirectory = try makeDirectory()
    defer {
      try? FileManager.default.removeItem(at: frameworksDirectory)
      try? FileManager.default.removeItem(at: resourcesDirectory)
    }
    try makeBundle(
      "AcmeAttribution.framework",
      in: frameworksDirectory,
      info: ["CFBundleIdentifier": "com.acme.attribution", "CFBundleShortVersionString": "3.2.1"]
    )
    try makeBundle(
      "AcmeKit_AcmeKit.bundle",
      in: resourcesDirectory,
      info: ["CFBundleIdentifier": "acme-kit.AcmeKit.resources"]
    )
    var sources = sources(
      frameworks: frameworksDirectory,
      classNames: ["AcmeAnalytics.Tracker", "ACMEPurchaseObserver", "MyAppHelperView"]
    )
    sources.resourcesDirectory = resourcesDirectory
    let info = SDKEnvironmentLogic.collect(from: sources)
    let superwall = Superwall(dependencyContainer: DependencyContainer(cache: CacheMock()))

    let result = await superwall.track(PrivateSuperwallEvent.SDKEnvironment(info: info))

    let payloads = try [info.toDictionary(), result.parameters.audienceFilterParams].map { dictionary in
      String(bytes: try JSONSerialization.data(withJSONObject: dictionary), encoding: .utf8) ?? ""
    }
    let rawNames = [
      "AcmeAnalytics", "Tracker", "ACMEPurchaseObserver", "MyAppHelperView",
      "AcmeAttribution", "com.acme.attribution", "AcmeKit_AcmeKit", "acme-kit.AcmeKit.resources"
    ]
    for payload in payloads {
      for name in rawNames {
        #expect(!payload.contains(name), "\(name) is in the event")
      }
      // Versions aren't names, and stay readable.
      #expect(payload.contains("3.2.1"))
    }
    #expect(info.objcClassNames.count == 2)
    withExtendedLifetime(superwall) {}
  }

  // MARK: - SDK hash

  @Test func sdkHash_doesNotDependOnOrder() throws {
    let classNames = ["Mixpanel.MixpanelInstance", "RevenueCat.Purchases", "FIRApp", "Branch"]
    let frameworks = [
      SDKEnvironmentInfo.EmbeddedBundle(name: "AppsFlyerLib", bundleId: "com.appsflyer.sdk.lib", version: "6.15.0"),
      SDKEnvironmentInfo.EmbeddedBundle(name: "OneSignalCore", bundleId: "com.onesignal.OneSignalCore", version: "1.0")
    ]

    let first = SDKEnvironmentLogic.sdkHash(
      modules: ["Mixpanel", "RevenueCat"],
      objcClassPrefixes: ["FIR", "Branch"],
      frameworks: frameworks,
      resourceBundles: []
    )
    let second = SDKEnvironmentLogic.sdkHash(
      modules: ["RevenueCat", "Mixpanel"],
      objcClassPrefixes: ["Branch", "FIR", "Branch"],
      frameworks: frameworks.reversed(),
      resourceBundles: []
    )
    let collected = SDKEnvironmentLogic.collect(from: sources(classNames: classNames)).sdkHash
    let collectedShuffled = SDKEnvironmentLogic.collect(from: sources(classNames: classNames.reversed())).sdkHash

    #expect(first == second)
    #expect(collected == collectedShuffled)
  }

  @Test func sdkHash_changesWhenAnSDKIsAddedOrUpgraded() {
    let frameworks = [
      SDKEnvironmentInfo.EmbeddedBundle(name: "AppsFlyerLib", bundleId: "com.appsflyer.sdk.lib", version: "6.15.0")
    ]
    func hash(
      modules: [String] = ["Mixpanel"],
      objcClassPrefixes: [String] = ["FIR"],
      frameworks: [SDKEnvironmentInfo.EmbeddedBundle] = frameworks,
      resourceBundles: [SDKEnvironmentInfo.EmbeddedBundle] = []
    ) -> String {
      return SDKEnvironmentLogic.sdkHash(
        modules: modules,
        objcClassPrefixes: objcClassPrefixes,
        frameworks: frameworks,
        resourceBundles: resourceBundles
      )
    }
    let original = hash()

    #expect(hash(modules: ["Mixpanel", "RevenueCat"]) != original)
    #expect(hash(objcClassPrefixes: ["FIR", "RC"]) != original)
    #expect(hash(frameworks: frameworks + [.init(name: "Sentry", bundleId: "io.sentry.Sentry", version: "8.58.4")]) != original)
    #expect(hash(resourceBundles: [.init(name: "Adjust_Adjust", bundleId: nil, version: nil)]) != original)
    #expect(hash(frameworks: [.init(name: "AppsFlyerLib", bundleId: "com.appsflyer.sdk.lib", version: "6.16.0")]) != original)
    // A list moving from one field to another is a different app too.
    #expect(hash(modules: [], objcClassPrefixes: ["FIR", "Mixpanel"]) != original)
  }

  @Test func sdkHash_changesWhenAnSDKsClassesAppear() {
    let info: [String: Any] = ["CFBundleExecutable": "MyApp"]
    let classNames = ["MyApp.AppDelegate", "Mixpanel.MixpanelInstance", "FIRApp"]
    func hash(adding added: [String]) -> String {
      return SDKEnvironmentLogic.scan(from: sources(info: info, classNames: classNames + added)).sdkHash
    }
    let original = hash(adding: [])

    #expect(hash(adding: ["RevenueCat.Purchases"]) != original)
    #expect(hash(adding: ["GADBannerView"]) != original)
    #expect(hash(adding: ["Branch"]) != original)
    #expect(hash(adding: ["PodsDummy_Adjust"]) != original)
  }

  // Most releases add classes to the app. Sending every class's hash again from
  // every install each time would be a few hundred kilobytes apiece.
  @Test func sdkHash_staysTheSameWhenTheAppOnlyAddsItsOwnClasses() {
    let info: [String: Any] = ["CFBundleExecutable": "MyApp"]
    let classNames = ["MyApp.AppDelegate", "XYZHomeViewController", "Mixpanel.MixpanelInstance", "FIRApp"]
    let firstRelease = SDKEnvironmentLogic.scan(from: sources(info: info, classNames: classNames))
    let nextRelease = SDKEnvironmentLogic.scan(
      from: sources(
        info: info,
        classNames: classNames + ["MyApp.SettingsModel", "XYZSettingsViewController", "FIRMessaging"]
      )
    )

    #expect(firstRelease.sdkHash == nextRelease.sdkHash)
    // What's sent when something does change is still every class.
    #expect(firstRelease.objcClassNames.count == 2)
    #expect(nextRelease.objcClassNames.count == 4)
  }

  // An app can load an embedded framework later on, so whether its classes are
  // there on app open depends on how the app was opened.
  @Test func sdkHash_ignoresWhichEmbeddedFrameworksAreLoaded() {
    let classNames = ["Mixpanel.MixpanelInstance", "FIRApp"]
    let notLoaded = SDKEnvironmentLogic.scan(from: sources(classNames: classNames))
    let loaded = SDKEnvironmentLogic.scan(
      from: sources(classNames: classNames, embeddedClassNames: ["Checkout.Session", "CKOCardView"])
    )
    var loadedSystemFramework = sources(classNames: classNames + ["Charts.Renderer"])
    loadedSystemFramework.systemModules = { ["Charts"] }
    let withoutSystemFramework = SDKEnvironmentLogic.scan(from: sources(classNames: classNames + ["Charts.Renderer"]))

    #expect(notLoaded.sdkHash == loaded.sdkHash)
    #expect(SDKEnvironmentLogic.scan(from: loadedSystemFramework).sdkHash == withoutSystemFramework.sdkHash)
    // The classes that were loaded are still sent.
    #expect(loaded.swiftModules == ["Checkout", "Mixpanel"])
    #expect(loaded.objcClassNames == ["CKOCardView", "FIRApp"])
  }

  @Test func sdkHash_ignoresTheAppVersionAndBuildSettings() {
    let classNames = ["Mixpanel.MixpanelInstance", "FIRApp"]
    let firstBuild = SDKEnvironmentLogic.collect(
      from: sources(
        info: [
          "CFBundleExecutable": "MyApp",
          "CFBundleShortVersionString": "1.0",
          "CFBundleVersion": "1",
          "DTXcode": "2600",
          "DTSDKName": "iphoneos26.0",
          "MinimumOSVersion": "16.0"
        ],
        classNames: classNames
      )
    )
    let nextBuild = SDKEnvironmentLogic.collect(
      from: sources(
        info: [
          "CFBundleExecutable": "MyApp",
          "CFBundleShortVersionString": "2.0",
          "CFBundleVersion": "57",
          "DTXcode": "2601",
          "DTSDKName": "iphonesimulator26.1",
          "MinimumOSVersion": "17.0",
          SDKEnvironmentLogic.trackingUsageDescriptionKey: "Ads",
          "SKAdNetworkItems": [["SKAdNetworkIdentifier": "cstr6suwn9.skadnetwork"]]
        ],
        classNames: classNames
      )
    )

    #expect(firstBuild.xcodeVersion != nextBuild.xcodeVersion)
    #expect(firstBuild.sdkHash == nextBuild.sdkHash)
  }

  @Test func sdkHash_ignoresWhereTheAppIsInstalled() throws {
    // The Simulator moves the app to a new container on every install.
    let firstInstall = try makeDirectory()
    let secondInstall = try makeDirectory()
    defer {
      try? FileManager.default.removeItem(at: firstInstall)
      try? FileManager.default.removeItem(at: secondInstall)
    }
    for directory in [firstInstall, secondInstall] {
      try makeBundle(
        "AppsFlyerLib.framework",
        in: directory,
        info: ["CFBundleIdentifier": "com.appsflyer.sdk.lib", "CFBundleShortVersionString": "6.15.0"]
      )
    }

    let first = SDKEnvironmentLogic.collect(from: sources(frameworks: firstInstall)).sdkHash
    let second = SDKEnvironmentLogic.collect(from: sources(frameworks: secondInstall)).sdkHash

    #expect(first == second)
  }

  // MARK: - Info.plist

  @Test func infoPlistFields_areRead() {
    let info = SDKEnvironmentLogic.collect(
      from: sources(
        info: [
          "DTXcode": "2601",
          "DTSDKName": "iphoneos26.0",
          "MinimumOSVersion": "17.2",
          SDKEnvironmentLogic.trackingUsageDescriptionKey: "We use this to measure ads.",
          "SKAdNetworkItems": [
            ["SKAdNetworkIdentifier": "cstr6suwn9.skadnetwork"],
            ["SKAdNetworkIdentifier": "4fzdc2evr5.skadnetwork"]
          ]
        ]
      )
    )

    #expect(info.xcodeVersion == "2601")
    #expect(info.buildSDKName == "iphoneos26.0")
    #expect(info.minimumOSVersion == "17.2")
    #expect(info.hasTrackingUsageDescription)
    #expect(info.skAdNetworkItemCount == 2)
  }

  @Test func trackingUsageDescriptionKey_isTheTrackingKey() {
    #expect(SDKEnvironmentLogic.trackingUsageDescriptionKey == "NSUser" + "TrackingUsageDescription")
    #expect(SDKEnvironmentLogic.trackingUsageDescriptionKey == PermissionHandler.PlistKey.tracking)
  }

  @Test func infoPlistFields_whenMissing() {
    let info = SDKEnvironmentLogic.collect(
      from: sources(info: ["LSMinimumSystemVersion": "14.0", "DTXcode": ""])
    )

    #expect(info.xcodeVersion == nil)
    #expect(info.buildSDKName == nil)
    #expect(info.minimumOSVersion == "14.0")
    #expect(!info.hasTrackingUsageDescription)
    #expect(info.skAdNetworkItemCount == 0)
  }

  // MARK: - Payload

  @Test func toDictionary_usesShapesThatSurviveEventParameters() {
    let info = SDKEnvironmentInfo.stub()
    let dictionary = info.toDictionary()
    let hash = SDKEnvironmentLogic.encodedNameHash

    #expect(dictionary["sdk_environment_sha256"] as? String == info.sdkHash)
    #expect(dictionary["name_hash_encoding"] as? String == "sha256-64+base64")
    #expect(dictionary["swift_module_hashes"] as? String == SDKEnvironmentLogic.nameHashes(["Mixpanel", "RevenueCat"]).encoded)
    #expect(dictionary["swift_module_count"] as? Int == 2)
    #expect(dictionary["swift_module_hashes_truncated"] as? Bool == false)
    #expect(dictionary["objc_class_name_hashes"] as? String == SDKEnvironmentLogic.nameHashes(["FIRApp", "Branch"]).encoded)
    #expect(dictionary["objc_class_name_count"] as? Int == 2)
    #expect(dictionary["objc_class_name_hashes_truncated"] as? Bool == false)
    #expect(dictionary["resource_bundle_hashes"] as? String == hash("Mixpanel_Mixpanel"))
    #expect(dictionary["resource_bundle_count"] as? Int == 1)
    #expect(dictionary["resource_bundle_hashes_truncated"] as? Bool == false)
    let frameworks = dictionary["embedded_frameworks"] as? [String: [String: String]]
    #expect(frameworks?[hash("AppsFlyerLib")] == ["bundle_id_hash": hash("com.appsflyer.sdk.lib"), "version": "6.15.0"])
    #expect(frameworks?[hash("Firestore")] == [:])
    #expect(dictionary["embedded_framework_count"] as? Int == 2)
    #expect(dictionary["xcode_version"] as? String == "2601")
    #expect(dictionary["build_sdk_name"] as? String == "iphoneos26.0")
    #expect(dictionary["minimum_os_version"] == nil)
    #expect(dictionary["has_tracking_usage_description"] as? Bool == true)
    #expect(dictionary["skadnetwork_item_count"] as? Int == 3)
  }

  // MARK: - Event

  @Test func event_isTrackedButNeverReachesTheDelegate() async {
    let dependencyContainer = DependencyContainer(cache: CacheMock())
    let superwall = Superwall(dependencyContainer: dependencyContainer)
    let delegate = MockSuperwallDelegate()
    dependencyContainer.delegateAdapter.swiftDelegate = delegate

    let result = await superwall.track(PrivateSuperwallEvent.SDKEnvironment(info: .stub()))
    // A public event, to show the delegate is listening.
    await superwall.track(InternalSuperwallEvent.AppOpen())

    let params = result.parameters.audienceFilterParams
    #expect(params["$event_name"] as? String == "sdk_environment")
    #expect(params["$is_standard_event"] as? Bool == true)
    #expect(params["$name_hash_encoding"] as? String == "sha256-64+base64")
    #expect(result.isQueuedForSending)
    #expect(delegate.eventInfosReceived.map(\.event.description) == ["app_open"])
    #expect(!SuperwallEventObjc.allCases.contains { $0.description == "sdk_environment" })
    #expect(!PrivateSuperwallEvent.SDKEnvironment(info: .stub()).canImplicitlyTriggerPaywall)
    withExtendedLifetime((superwall, dependencyContainer)) {}
  }

  // With every class's hash in it, the event is big. A request the server turned
  // away for its size would take the app launch events with it.
  @Test func event_goesUpInARequestOfItsOwn() async {
    let dependencyContainer = DependencyContainer(cache: CacheMock())
    let superwall = Superwall(dependencyContainer: dependencyContainer)

    await superwall.track(InternalSuperwallEvent.AppOpen())
    let result = await superwall.track(PrivateSuperwallEvent.SDKEnvironment(info: .stub()))

    let queued = await dependencyContainer.placementsQueue.queuedEventNames
    #expect(PrivateSuperwallEvent.SDKEnvironment(info: .stub()).isSentInOwnRequest)
    #expect(!InternalSuperwallEvent.AppOpen().isSentInOwnRequest)
    #expect(result.isQueuedForSending)
    #expect(queued.contains("app_open"))
    #expect(!queued.contains("sdk_environment"))
    withExtendedLifetime((superwall, dependencyContainer)) {}
  }

  // The queue hears of a tracking change a moment after the options do.
  @Test func liveReporter_whenTrackingWasJustTurnedOff_sendsNothing() async {
    let dependencyContainer = DependencyContainer(cache: CacheMock())
    let superwall = Superwall(dependencyContainer: dependencyContainer)
    let reporter = SDKEnvironmentReporter.live(superwall: superwall)
    dependencyContainer.configManager.options.eventTrackingBehavior = .none

    let didSend = await reporter.send(.stub())

    #expect(!didSend)
    #expect(await dependencyContainer.placementsQueue.queuedEventNames.isEmpty)
    withExtendedLifetime((superwall, dependencyContainer)) {}
  }

  // MARK: - Collector

  @Test func collector_collectsOncePerProcess() async {
    let lookups = Counter()
    var sources = sources()
    sources.classNames = {
      lookups.increment()
      return LinkedCodeLogic.AppClassNames(executable: ["RevenueCat.PurchasesOrchestrator"])
    }
    let collector = SDKEnvironmentCollector(sources: sources)

    async let first = collector.scan()
    async let second = collector.scan()
    let results = await [first, second]
    let third = await collector.scan()

    #expect(results.allSatisfy { $0.swiftModules == ["RevenueCat"] })
    #expect(third.swiftModules == ["RevenueCat"])
    #expect(lookups.value == 1)
  }

  // MARK: - Sending only when the SDKs change

  @Test func reporter_withNoSavedHash_sendsAndSaves() async {
    let reporter = ReporterHarness(scan: .stub(), savedHash: nil)

    let didSend = await reporter.reporter.reportIfChanged()

    #expect(didSend)
    #expect(reporter.sent.value == 1)
    #expect(reporter.storedHash.value == SDKEnvironmentInfo.stub().sdkHash)
  }

  @Test func reporter_withTheSameHash_sendsNothing() async {
    let reporter = ReporterHarness(scan: .stub(), savedHash: SDKEnvironmentInfo.stub().sdkHash)

    let didSend = await reporter.reporter.reportIfChanged()

    #expect(!didSend)
    #expect(reporter.sent.value == 0)
    #expect(reporter.storedHash.value == SDKEnvironmentInfo.stub().sdkHash)
  }

  @Test func reporter_withADifferentHash_sendsAndSavesTheNewOne() async {
    let reporter = ReporterHarness(scan: .stub(), savedHash: "the hash of an older build's SDKs")

    let firstOpen = await reporter.reporter.reportIfChanged()
    let nextOpen = await reporter.reporter.reportIfChanged()

    #expect(firstOpen)
    #expect(!nextOpen)

    #expect(reporter.sent.value == 1)
    #expect(reporter.storedHash.value == SDKEnvironmentInfo.stub().sdkHash)
  }

  @Test func reporter_whenTheEventIsNotQueued_keepsTheOldHash() async {
    // As with `eventTrackingBehavior` set to `.none`.
    let reporter = ReporterHarness(scan: .stub(), savedHash: "old", isQueued: false)

    let didSend = await reporter.reporter.reportIfChanged()

    #expect(!didSend)
    #expect(reporter.sent.value == 1)
    #expect(reporter.storedHash.value == "old")
  }

  @Test func reportOnce_withOverlappingCalls_sendsOnce() async {
    let reporter = ReporterHarness(scan: .stub(), savedHash: nil, sendDelay: 50_000_000)
    let once = SDKEnvironmentReportOnce()

    async let first = once.run { reporter.reporter }
    async let second = once.run { reporter.reporter }
    let results = await [first, second]
    let later = await once.run { reporter.reporter }

    #expect(results == [true, true])
    #expect(later)
    #expect(reporter.sent.value == 1)
    #expect(reporter.storedHash.value == SDKEnvironmentInfo.stub().sdkHash)
  }

  @Test func savedHash_isOnePerInstallAndSurvivesReset() {
    // `reset()` clears the cache and user-specific documents, never these.
    #expect(SDKEnvironmentHash.directory == .appSpecificDocuments)
    #expect(SDKEnvironmentHash.key == "store.sdkEnvironmentHash")
  }

  // MARK: - App open

  @Test func checksOnAppOpenNotEverySession() async {
    let dependencyContainer = DependencyContainer()
    // `AppSessionManager` holds its delegate `unowned`.
    let delegate = AppManagerDelegateMock()
    // Not `.default`, so lifecycle notifications from other suites can't reach it.
    let notificationCenter = NotificationCenter()
    let checks = Counter()
    let appSessionManager = AppSessionManager(
      configManager: dependencyContainer.configManager,
      identityManager: dependencyContainer.identityManager,
      storage: dependencyContainer.storage,
      delegate: delegate,
      republishIfAdConsentChanged: {},
      notificationCenter: notificationCenter,
      trackSDKEnvironment: { checks.increment() }
    )
    // Any time away starts a new session.
    appSessionManager.appSessionTimeout = 0

    await appSessionManager.didBecomeActive()
    #expect(checks.value == 1)

    // Leave and come back: a new session, but the same app open.
    // The observers are added asynchronously, so post until one has run.
    for _ in 0..<100 where appSessionManager.appSession.endAt == nil {
      notificationCenter.post(name: UIApplication.willResignActiveNotification, object: nil)
      try? await Task.sleep(nanoseconds: 10_000_000)
    }
    #expect(appSessionManager.appSession.endAt != nil)
    let firstSession = appSessionManager.appSession.id
    try? await Task.sleep(nanoseconds: 5_000_000)
    await appSessionManager.didBecomeActive()
    #expect(appSessionManager.appSession.id != firstSession)
    #expect(checks.value == 1)

    withExtendedLifetime((appSessionManager, delegate, dependencyContainer)) {}
  }

  // MARK: - Helpers

  private func sources(
    frameworks: URL? = nil,
    info: [String: Any] = [:],
    classNames: [String] = [],
    embeddedClassNames: [String] = []
  ) -> SDKEnvironmentSources {
    return SDKEnvironmentSources(
      frameworksDirectory: frameworks,
      resourcesDirectory: nil,
      infoDictionary: info,
      classNames: { LinkedCodeLogic.AppClassNames(executable: classNames, embedded: embeddedClassNames) },
      systemModules: { [] }
    )
  }

  /// Splits an encoded list back into its 8-byte hashes.
  private func decodedHashes(_ encoded: String) throws -> [[UInt8]] {
    let bytes = [UInt8](try #require(Data(base64Encoded: encoded)))
    try #require(bytes.count % SDKEnvironmentLogic.nameHashLength == 0)
    return stride(from: 0, to: bytes.count, by: SDKEnvironmentLogic.nameHashLength).map {
      Array(bytes[$0..<$0 + SDKEnvironmentLogic.nameHashLength])
    }
  }

  private func makeDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("SDKEnvironmentTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
  }

  /// Makes a bundle laid out as on iOS, with its Info.plist at the top.
  private func makeBundle(_ name: String, in directory: URL, info: [String: Any]?) throws {
    let url = directory.appendingPathComponent(name)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    guard let info = info else {
      return
    }
    let data = try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
    try data.write(to: url.appendingPathComponent("Info.plist"))
  }
}

/// An ``SDKEnvironmentReporter`` with its storage and sending recorded.
private struct ReporterHarness {
  let sent: Counter
  let storedHash: Box<String?>
  let reporter: SDKEnvironmentReporter

  init(
    scan: SDKEnvironmentScan,
    savedHash: String?,
    isQueued: Bool = true,
    sendDelay: UInt64 = 0
  ) {
    let storedHash = Box(savedHash)
    let sent = Counter()
    self.sent = sent
    self.storedHash = storedHash
    self.reporter = SDKEnvironmentReporter(
      scan: { scan },
      savedHash: { storedHash.value },
      saveHash: { storedHash.value = $0 },
      send: { _ in
        sent.increment()
        // Holds the send open, so overlapping reports would both read the old hash.
        try? await Task.sleep(nanoseconds: sendDelay)
        return isQueued
      }
    )
  }
}

private final class Box<Value>: @unchecked Sendable {
  private let lock = NSLock()
  private var _value: Value

  init(_ value: Value) {
    _value = value
  }

  var value: Value {
    get {
      lock.lock()
      defer { lock.unlock() }
      return _value
    }
    set {
      lock.lock()
      defer { lock.unlock() }
      _value = newValue
    }
  }
}

private final class Counter: @unchecked Sendable {
  private let lock = NSLock()
  private var count = 0

  var value: Int {
    lock.lock()
    defer { lock.unlock() }
    return count
  }

  func increment() {
    lock.lock()
    defer { lock.unlock() }
    count += 1
  }
}

extension SDKEnvironmentScan {
  static func stub(
    swiftModules: [String] = ["Mixpanel", "RevenueCat"],
    objcClassNames: [String] = ["FIRApp", "Branch"]
  ) -> SDKEnvironmentScan {
    let frameworks: [SDKEnvironmentInfo.EmbeddedBundle] = [
      .init(name: "AppsFlyerLib", bundleId: "com.appsflyer.sdk.lib", version: "6.15.0"),
      .init(name: "Firestore", bundleId: nil, version: nil)
    ]
    let resourceBundles: [SDKEnvironmentInfo.EmbeddedBundle] = [
      .init(name: "Mixpanel_Mixpanel", bundleId: nil, version: nil)
    ]
    return SDKEnvironmentScan(
      swiftModules: swiftModules,
      objcClassNames: objcClassNames,
      frameworks: frameworks,
      resourceBundles: resourceBundles,
      xcodeVersion: "2601",
      buildSDKName: "iphoneos26.0",
      minimumOSVersion: nil,
      hasTrackingUsageDescription: true,
      skAdNetworkItemCount: 3,
      sdkHash: SDKEnvironmentLogic.sdkHash(
        modules: swiftModules,
        objcClassPrefixes: LinkedCodeLogic.objcPrefixesAndUnprefixedNames(in: objcClassNames),
        frameworks: frameworks,
        resourceBundles: resourceBundles
      )
    )
  }
}

extension SDKEnvironmentInfo {
  static func stub() -> SDKEnvironmentInfo {
    return SDKEnvironmentScan.stub().info()
  }
}
