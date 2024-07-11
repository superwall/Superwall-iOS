//
//  File.swift
//  
//
//  Created by Yusuf Tör on 11/07/2024.
//

import XCTest
@testable import SuperwallKit

final class SWWebViewLoadingHandlerTests: XCTestCase {
  func test_loadURL_noDelegate() async {
    let handler = SWWebViewLoadingHandler(enableMultiplePaywallUrls: true)
    let didLoad = await handler.loadURL(
      paywallUrlConfig: .init(urls: [.stub()], maxAttempts: 2),
      paywallUrl: URL(string: "https://google.com")!
    )
    XCTAssertFalse(didLoad)
    XCTAssertTrue(handler.didFailToLoad)
  }

  func test_loadURL_disabledMultiplePaywallURLs_loadedURL() async {
    let delegate = LoadingDelegate(errorIndices: [])
    let handler = SWWebViewLoadingHandler(enableMultiplePaywallUrls: false)
    handler.loadingDelegate = delegate
    let didLoad = await handler.loadURL(
      paywallUrlConfig: .init(urls: [.stub()], maxAttempts: 2),
      paywallUrl: URL(string: "https://google.com")!
    )
    XCTAssertTrue(didLoad)
    XCTAssertFalse(handler.didFailToLoad)
  }

  func test_loadURL_disabledMultiplePaywallURLs_throwError() async {
    let delegate = LoadingDelegate(errorIndices: [0])
    let handler = SWWebViewLoadingHandler(enableMultiplePaywallUrls: false)
    handler.loadingDelegate = delegate
    let didLoad = await handler.loadURL(
      paywallUrlConfig: .init(urls: [.stub()], maxAttempts: 2),
      paywallUrl: URL(string: "https://google.com")!
    )
    // TODO: Make sure webview failure is tracked
    XCTAssertFalse(didLoad)
    XCTAssertTrue(handler.didFailToLoad)
  }

  func test_loadURL_tooManyAttempts() async {
    let delegate = LoadingDelegate(errorIndices: [])
    let handler = SWWebViewLoadingHandler(enableMultiplePaywallUrls: true)
    handler.loadingDelegate = delegate
    let didLoad = await handler.loadURL(
      attempts: 2,
      paywallUrlConfig: .init(urls: [.stub()], maxAttempts: 2),
      paywallUrl: URL(string: "https://google.com")!
    )
    // TODO: Make sure webview failure is tracked
    XCTAssertFalse(didLoad)
    XCTAssertTrue(handler.didFailToLoad)
  }

  func test_loadURL_noEndpoints() async {
    let delegate = LoadingDelegate(errorIndices: [])
    let handler = SWWebViewLoadingHandler(enableMultiplePaywallUrls: true)
    handler.loadingDelegate = delegate
    let didLoad = await handler.loadURL(
      attempts: 2,
      paywallUrlConfig: .init(urls: [], maxAttempts: 2),
      paywallUrl: URL(string: "https://google.com")!
    )
    // TODO: Make sure webview failure is tracked
    XCTAssertFalse(didLoad)
    XCTAssertTrue(handler.didFailToLoad)
  }

  func test_loadURL_loadFirstUrl() async {
    let delegate = LoadingDelegate(errorIndices: [])
    let handler = SWWebViewLoadingHandler(enableMultiplePaywallUrls: true)
    handler.loadingDelegate = delegate
    let didLoad = await handler.loadURL(
      paywallUrlConfig: .init(urls: [.stub()], maxAttempts: 2),
      paywallUrl: URL(string: "https://google.com")!
    )
    XCTAssertTrue(didLoad)
    XCTAssertFalse(handler.didFailToLoad)
  }

  func test_loadURL_loadSecondUrl() async {
    let delegate = LoadingDelegate(errorIndices: [0])
    let handler = SWWebViewLoadingHandler(enableMultiplePaywallUrls: true)
    handler.loadingDelegate = delegate
    let didLoad = await handler.loadURL(
      paywallUrlConfig: .init(urls: [.stub(), .stub()], maxAttempts: 2),
      paywallUrl: URL(string: "https://google.com")!
    )
    // TODO: Make sure webview failure is tracked
    XCTAssertTrue(didLoad)
    XCTAssertFalse(handler.didFailToLoad)
  }

  func test_loadURL_loadNoUrls() async {
    let delegate = LoadingDelegate(errorIndices: [0, 1])
    let handler = SWWebViewLoadingHandler(enableMultiplePaywallUrls: true)
    handler.loadingDelegate = delegate
    let didLoad = await handler.loadURL(
      paywallUrlConfig: .init(urls: [.stub(), .stub()], maxAttempts: 2),
      paywallUrl: URL(string: "https://google.com")!
    )
    // TODO: Make sure webview failure is tracked
    XCTAssertFalse(didLoad)
    XCTAssertTrue(handler.didFailToLoad)
  }

  func test_loadURL_threeURLs_tooManyAttempts() async {
    let delegate = LoadingDelegate(errorIndices: [0, 1])
    let handler = SWWebViewLoadingHandler(enableMultiplePaywallUrls: true)
    handler.loadingDelegate = delegate
    let didLoad = await handler.loadURL(
      paywallUrlConfig: .init(urls: [.stub(), .stub(), .stub()], maxAttempts: 2),
      paywallUrl: URL(string: "https://google.com")!
    )
    // TODO: Make sure webview failure is tracked
    XCTAssertFalse(didLoad)
    XCTAssertTrue(handler.didFailToLoad)
  }
}

final class LoadingDelegate: SWWebViewLoadingDelegate {
  let errorIndices: [Int]
  var index = 0

  init(errorIndices: [Int]) {
    self.errorIndices = errorIndices
  }

  func loadWebView(with url: URL, timeout: TimeInterval?) async throws {
    if errorIndices.contains(index) {
      index += 1
      throw NetworkError.unknown
    }
    index += 1
  }
}
