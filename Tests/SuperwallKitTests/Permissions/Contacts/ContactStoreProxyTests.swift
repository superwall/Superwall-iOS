//
//  ContactStoreProxyTests.swift
//  SuperwallKitTests
//
//  Created by Yusuf Tör on 11/08/2026.
//

import Foundation
import Testing
@testable import SuperwallKit

@Suite
struct ContactStoreProxyTests {
  @Test func mangledClassName_decodesCorrectly() {
    let className = ContactStoreProxy.mangledContactStoreClassName.rot13()
    #expect(className == "CNContactStore")
  }

  @Test func selectorNames_areCorrectlyDecoded() {
    let proxy = ContactStoreProxy()

    #expect(proxy.authorizationStatusSelectorName == "authorizationStatusForEntityType:")
    #expect(proxy.requestAccessSelectorName == "requestAccessForEntityType:completionHandler:")
  }
}

/// `ContactStoreProxy` carried the same `@objc` fake as the other handlers. Pin its
/// guarded path, so the deleted `FakeContactStore` can't quietly return.
@Suite
struct ContactStoreProxyMissingClassTests {
  /// -1 is the "unavailable" sentinel `checkContactsPermission()` maps to
  /// `.unsupported`, and is what the fake's class method returned.
  @Test func missingStore_authorizationStatus_returnsUnavailable() {
    let proxy = ContactStoreProxy(contactStoreClass: nil)
    #expect(proxy.authorizationStatus() == -1)
  }

  @Test func missingStore_requestPermission_returnsFalse() async throws {
    let proxy = ContactStoreProxy(contactStoreClass: nil)
    let granted = try await proxy.requestPermission()
    #expect(granted == false)
  }
}
