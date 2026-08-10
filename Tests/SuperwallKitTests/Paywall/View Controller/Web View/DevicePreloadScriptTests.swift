//
//  DevicePreloadScriptTests.swift
//  SuperwallKitTests
//
//  Created by Superwall on 10/08/2026.
//

import Testing
@testable import SuperwallKit

struct DevicePreloadScriptTests {
  @Test("Wraps the device locale in the preload global")
  func wrapsLocaleInPreloadGlobal() {
    let source = DevicePreloadScript.source(deviceLocale: "en_US")
    #expect(source == #"window.__SW_DEVICE_PRELOAD__ = {"deviceLocale":"en_US"};"#)
  }

  @Test("Escapes characters that would otherwise break out of the script")
  func escapesUnsafeCharacters() throws {
    let source = try #require(DevicePreloadScript.source(deviceLocale: #"en"};alert(1);//"#))
    #expect(source.hasPrefix("window.__SW_DEVICE_PRELOAD__ = {"))
    #expect(source.hasSuffix("};"))
    #expect(source.contains(#"\""#))
    #expect(!source.contains(#""en"};"#))
  }

  @Test("Handles non-ASCII locale identifiers")
  func handlesNonAsciiLocales() throws {
    let source = try #require(DevicePreloadScript.source(deviceLocale: "zh_Hans_CN"))
    #expect(source.contains("zh_Hans_CN"))
  }
}
