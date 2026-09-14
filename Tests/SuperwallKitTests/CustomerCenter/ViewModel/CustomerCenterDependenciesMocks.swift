//
//  CustomerCenterDependenciesMocks.swift
//
//
//  Created by Jordan Morgan on 20/08/2026.
//

import Combine
import Foundation
@testable import SuperwallKit

final class CustomerInfoProviderMock: CustomerCenterCustomerInfoProviding {
  let subject: CurrentValueSubject<CustomerInfo, Never>
  var fetchCount = 0
  var refreshReceiptsCount = 0
  /// `true` once the view model asked for a receipt-backed refresh rather than a cached read.
  var didRefreshReceipts: Bool { refreshReceiptsCount > 0 }
  init(_ info: CustomerInfo) { subject = .init(info) }
  func fetchCustomerInfo() async -> CustomerInfo { fetchCount += 1; return subject.value }
  func refreshReceipts() async -> CustomerInfo { refreshReceiptsCount += 1; return subject.value }
  var customerInfoPublisher: AnyPublisher<CustomerInfo, Never> { subject.eraseToAnyPublisher() }
}
final class ProductsProviderMock: CustomerCenterProductsProviding {
  var products: [String: ProductDisplayInfo] = [:]
  var requested: Set<String> = []
  func products(for ids: Set<String>) async -> [String: ProductDisplayInfo] { requested = ids; return products.filter { ids.contains($0.key) } }
}
final class RestorerMock: CustomerCenterRestoring {
  var result: RestorationResult = .restored
  var calls = 0
  func restorePurchases() async -> RestorationResult { calls += 1; return result }
}
final class URLOpenerMock: CustomerCenterURLOpening {
  var canOpenURLs = true
  var openable = true
  var opened: [URL] = []
  func canOpen(_ url: URL) -> Bool { openable }
  func open(_ url: URL) { opened.append(url) }
}
final class EventTrackerMock: CustomerCenterEventTracking {
  var events: [SuperwallEvent] = []
  func track(_ event: Trackable) async {
    if let event = event as? TrackableSuperwallEvent { events.append(event.superwallEvent) }
  }
}
struct EnvironmentMock: CustomerCenterEnvironmentProviding {
  var appVersion = "1.0.0"
  var osVersion = "18.0"
  var deviceModel = "iPhone"
  var sdkVersion = "4.17.0"
  var userId = "user_1"
  var isSandbox = false
  var appStoreURL: URL? = URL(string: "https://apps.apple.com/app/id1")
  var webManagementURL: URL?
  var isSimulator = false
  var isAppExtension = false
  var originalDownloadDate: Date? = Date(timeIntervalSince1970: 0)
  var locale = Locale(identifier: "en_US")

  init(
    appVersion: String = "1.0.0",
    osVersion: String = "18.0",
    deviceModel: String = "iPhone",
    sdkVersion: String = "4.17.0",
    userId: String = "user_1",
    isSandbox: Bool = false,
    appStoreURL: URL? = URL(string: "https://apps.apple.com/app/id1"),
    webManagementURL: URL? = nil,
    isSimulator: Bool = false,
    isAppExtension: Bool = false,
    originalDownloadDate: Date? = Date(timeIntervalSince1970: 0),
    locale: Locale = Locale(identifier: "en_US")
  ) {
    self.appVersion = appVersion
    self.osVersion = osVersion
    self.deviceModel = deviceModel
    self.sdkVersion = sdkVersion
    self.userId = userId
    self.isSandbox = isSandbox
    self.appStoreURL = appStoreURL
    self.webManagementURL = webManagementURL
    self.isSimulator = isSimulator
    self.isAppExtension = isAppExtension
    self.originalDownloadDate = originalDownloadDate
    self.locale = locale
  }
}
final class AppStoreVersionProviderMock: CustomerCenterAppStoreVersionProviding {
  var version: String?
  var callCount = 0
  init(version: String? = nil) { self.version = version }
  func latestAppStoreVersion() async -> String? { callCount += 1; return version }
}

extension CustomerCenterDependencies {
  static func mock(
    info: CustomerInfo,
    products: [String: ProductDisplayInfo] = [:],
    environment: EnvironmentMock = EnvironmentMock(),
    restorer: RestorerMock = RestorerMock(),
    urlOpener: URLOpenerMock = URLOpenerMock(),
    tracker: EventTrackerMock = EventTrackerMock(),
    lookup: StoreKitTransactionLookupMock = StoreKitTransactionLookupMock(),
    appStoreVersion: AppStoreVersionProviderMock = AppStoreVersionProviderMock()
  ) -> (CustomerCenterDependencies, CustomerInfoProviderMock, ProductsProviderMock) {
    let infoProvider = CustomerInfoProviderMock(info)
    let productsProvider = ProductsProviderMock()
    productsProvider.products = products
    let deps = CustomerCenterDependencies(
      customerInfo: infoProvider,
      products: productsProvider,
      restore: restorer,
      urlOpener: urlOpener,
      tracker: tracker,
      environment: environment,
      transactionLookup: lookup,
      appStoreVersion: appStoreVersion
    )
    return (deps, infoProvider, productsProvider)
  }
}
