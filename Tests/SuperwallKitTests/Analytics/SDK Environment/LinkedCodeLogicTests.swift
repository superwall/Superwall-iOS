//
//  LinkedCodeLogicTests.swift
//  SuperwallKit
//
//  Created by Jake Mor on 23/10/2026.
//

import Foundation
import Testing
@testable import SuperwallKit

struct LinkedCodeLogicTests {
  // MARK: - Swift modules

  // Each form was seen in a real app's class list.
  @Test(arguments: [
    ("PhotoFilter.FilterAttribute", "PhotoFilter"),
    ("Nuke.ImagePipeline.Configuration", "Nuke"),
    ("_TtC11PhotoFilterP33_3ACE56F68848EA33F46463A61355926A19ResourceBundleClass", "PhotoFilter"),
    ("_TtCC12SuperwallKit12_ASN1Decoder5State", "SuperwallKit"),
    ("_TtCCC15CIFilterFactory4CIFF13AreaHistogramP33_24EDFC460F02D9468C447F4A6B8CDB5833Filter", "CIFilterFactory"),
    ("_TtCV9Superwall20RootTabBarVisibility10Controller", "Superwall"),
    ("_TtCO4Nuke13ImageDecoders7Default", "Nuke"),
    ("_TtCFIZvC5Kanna12CloudSessionP33_C4A82E79DFB68FFA9B495AD3890996D811noRedirects", "Kanna"),
    ("_TtCs12_SwiftObject", "Swift"),
    ("_TtCSo8NSObject4Foo", "__C")
  ])
  func swiftModule_isParsedFromEachNameForm(name: String, module: String) {
    #expect(LinkedCodeLogic.swiftModule(ofClassName: name) == module)
  }

  @Test(arguments: ["FIRApp", "AppsFlyerLib", "_TtC99Short", "_TtC", ".Leading", "_Tt"])
  func swiftModule_isNilForObjectiveCAndMalformedNames(name: String) {
    #expect(LinkedCodeLogic.swiftModule(ofClassName: name) == nil)
  }

  // MARK: - Objective-C prefixes

  // Only used to recognise Apple's and SuperwallKit's classes.
  @Test(arguments: [
    ("FIRApp", "FIR"),
    ("GULAppDelegateSwizzler", "GUL"),
    ("TTSDKHTTPClient", "TTSDKHTTP")
  ])
  func objcPrefix_isTheCapitalsBeforeTheFirstWord(name: String, prefix: String) {
    #expect(LinkedCodeLogic.objcPrefix(ofClassName: name) == prefix)
  }

  @Test(arguments: ["Branch", "AppsFlyerLib", "URL", "FIRCLS", "_PrivateThing"])
  func objcPrefix_isNilWithoutTwoLeadingCapitals(name: String) {
    #expect(LinkedCodeLogic.objcPrefix(ofClassName: name) == nil)
  }

  // MARK: - Filtering

  @Test func modulesAndObjCClassNames_leaveOutTheAppAndSuperwall() {
    let classNames = [
      "MyApp.ContentView", "_TtC5MyAppP33_0123456789ABCDEF0123456789ABCDEF4Item",
      "SuperwallKit.PaywallViewController", "Superscript.Evaluator",
      "SWKPaywallInfo", "SWKProduct",
      "Mixpanel.MixpanelInstance", "RevenueCat.PurchasesOrchestrator", "Mixpanel.Flush",
      "FIRApp", "FIRCLSReport", "Branch", "FIRApp",
      "Firebase_FirebaseCrashlytics_SWIFTPM_MODULE_BUNDLER_FINDER"
    ]

    let linked = LinkedCodeLogic.modulesAndObjCClassNames(
      in: classNames,
      excludedModules: ["MyApp"],
      systemModules: []
    )

    #expect(linked.modules == ["Mixpanel", "RevenueCat"])
    #expect(linked.objcClassNames == [
      "Branch", "FIRApp", "FIRCLSReport", "Firebase_FirebaseCrashlytics_SWIFTPM_MODULE_BUNDLER_FINDER"
    ])
  }

  @Test func modulesAndObjCClassNames_leaveOutAppleAndToolchainNames() {
    let systemModules = Set(
      [
        "Foundation", "SwiftUI", "Combine", "UIKit", "StoreKit", "WebKit"
      ].map { "/System/Library/Frameworks/\($0).framework/\($0)" }
        .compactMap(LinkedCodeLogic.systemModule(atImagePath:))
        + ["/usr/lib/swift/libswiftObservation.dylib"].compactMap(LinkedCodeLogic.systemModule(atImagePath:))
    )
    let appleSwiftClasses = [
      "Foundation.Foo", "SwiftUI.HostingThing", "Combine.Sink", "Observation.Registrar",
      "UIKit.Helper", "StoreKit.Thing", "WebKit.Thing", "Swift.Thing",
      "_Concurrency.Thing", "_StringProcessing.Thing", "_SwiftUI_Private.Thing",
      "_TtCs12_SwiftObject", "_TtCSo6UIView5Inner"
    ]
    let appleObjCClasses = [
      "NS", "UI", "CA", "CK", "SK", "WK", "AV", "MK", "CL", "PK", "GK", "MTL", "NSURL", "UIKB"
    ].map { "\($0)Thing" }
    let underscored = (0..<3).map { "_UIPrivateThing\($0)" }

    let thirdParty = ["Adjust.Tracker", "ADJThing", "ADJOther", "Adjust"]

    let linked = LinkedCodeLogic.modulesAndObjCClassNames(
      in: appleSwiftClasses + appleObjCClasses + underscored + thirdParty,
      excludedModules: [],
      systemModules: systemModules
    )

    #expect(linked.modules == ["Adjust"])
    #expect(linked.objcClassNames == ["ADJOther", "ADJThing", "Adjust"])
  }

  @Test(arguments: [
    ("/System/Library/Frameworks/SwiftUI.framework/SwiftUI", "SwiftUI"),
    (
      "/Library/Developer/CoreSimulator/Volumes/iOS_23A343/Library/Developer/CoreSimulator/Profiles/Runtimes/"
        + "iOS 26.0.simruntime/Contents/Resources/RuntimeRoot/System/Library/Frameworks/UIKit.framework/UIKit",
      "UIKit"
    ),
    ("/System/iOSSupport/System/Library/Frameworks/UIKit.framework/Versions/A/UIKit", "UIKit"),
    ("/System/Library/PrivateFrameworks/StoreKitUI.framework/StoreKitUI", "StoreKitUI"),
    ("/usr/lib/swift/libswift_Concurrency.dylib", "_Concurrency"),
    ("/usr/lib/swift/libswiftObservation.dylib", "Observation"),
    ("/usr/lib/swift/libswiftCore.dylib", "Swift")
  ])
  func systemModule_isReadFromApplesImagePaths(path: String, module: String) {
    #expect(LinkedCodeLogic.systemModule(atImagePath: path) == module)
  }

  @Test func systemModule_isNilForTheAppsImages() {
    let app = "/private/var/containers/Bundle/Application/1234/My.app"
    #expect(LinkedCodeLogic.systemModule(atImagePath: "\(app)/My") == nil)
    #expect(LinkedCodeLogic.systemModule(atImagePath: "\(app)/Frameworks/Mixpanel.framework/Mixpanel") == nil)
    #expect(LinkedCodeLogic.systemModule(atImagePath: "/usr/lib/libobjc.A.dylib") == nil)
  }

  @Test func loadedSystemModules_coverTheProcesssAppleFrameworks() {
    let modules = LinkedCodeLogic.loadedSystemModules()
    #expect(modules.isSuperset(of: ["Foundation", "UIKit", "Swift"]))
  }

  // MARK: - Class names

  @Test func appClassNames_readTheImagesInsideTheBundle() {
    let testBundle = Bundle(for: AppSessionManagerTests.self).bundleURL

    let names = LinkedCodeLogic.appClassNames(bundleURL: testBundle)

    #expect(names.contains("SuperwallKitTests.AppSessionManagerTests"))
  }

  @Test func appClassNames_readImagesNestedInTheBundle() {
    let testBundle = Bundle(for: AppSessionManagerTests.self).bundleURL

    // The test bundle sits inside its parent like an embedded framework.
    let names = LinkedCodeLogic.appClassNames(bundleURL: testBundle.deletingLastPathComponent())

    #expect(names.contains("SuperwallKitTests.AppSessionManagerTests"))
  }

  @Test(arguments: [
    ("MyApp", true),
    ("MyApp.debug.dylib", true),
    ("Frameworks/Features.framework/Features", true),
    ("Frameworks/AppsFlyerLib.framework/AppsFlyerLib", true),
    ("Frameworks/libswift_Concurrency.dylib", false),
    ("Frameworks/SuperwallKit.framework/SuperwallKit", false),
    ("Frameworks/Superscript.framework/Superscript", false)
  ])
  func isThirdPartyImage_skipsSwiftLibrariesAndSuperwall(path: String, isThirdParty: Bool) {
    #expect(LinkedCodeLogic.isThirdPartyImage(atRelativePath: path) == isThirdParty)
  }

  @Test(arguments: [("Tapes Dev", "Tapes_Dev"), ("blank-app", "blank_app"), ("1Up", "_1Up"), ("Kanna", "Kanna")])
  func mainModuleName_isTheExecutableAsAnIdentifier(executable: String, module: String) {
    #expect(LinkedCodeLogic.mainModuleName(executableName: executable) == module)
  }
}
