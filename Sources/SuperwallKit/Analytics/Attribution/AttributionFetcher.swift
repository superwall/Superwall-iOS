//
//  File.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 23/09/2024.
//

import Foundation
#if canImport(AdServices)
import AdServices
#endif

final class AttributionFetcher {
  var integrationAttributes: [String: String] {
    queue.sync {
      _integrationAttributes
    }
  }
  private let queue = DispatchQueue(label: "com.superwall.attributionfetcher")
  private let timerQueue = DispatchQueue(label: "com.superwall.attributionfetcher.timer")
  private var redeemTimer: DispatchSourceTimer?
  private var activeObserver: NSObjectProtocol?
  private let vendorIdProvider: (() -> String)?
  private let attStatusProvider: (() -> Int?)?
  private let idfaProvider: (() -> String?)?
  private let syncUserAttributes: ([String: Any?]) -> Void
  private var _integrationAttributes: [String: String] = [:]

  /// The identifiers last handed to `syncUserAttributes`. Only a change
  /// is worth syncing: every sync costs a `user_attributes` event, a delegate
  /// callback, a Core Data row and a re-encode of the whole attribute dict.
  private var _lastSyncedDeviceIdentifiers: [String: String]?
  /// The identifiers a reset's new user was given, until the reset finishes.
  private var _resetDeviceIdentifiers: [String: String]?

  private unowned let storage: Storage
  private unowned let webEntitlementRedeemer: WebEntitlementRedeemer
  private unowned let deviceHelper: DeviceHelper

  var identifierForAdvertisers: String? {
    // should match available platforms here:
    // https://developer.apple.com/documentation/adsupport/asidentifiermanager/1614151-advertisingidentifier
    #if os(iOS) || os(macOS) || os(visionOS)
    let identifierManagerProxy = AttributionTypeFactory.asIdProxy()
    guard let identifierManagerProxy = identifierManagerProxy else {
      Logger.debug(
        logLevel: .warn,
        scope: .analytics,
        message: "AdSupport framework not imported. Attribution data incomplete."
      )
      return nil
    }

    guard let identifierValue = identifierManagerProxy.adsIdentifier else {
      return nil
    }

    // When ATT hasn't been authorized iOS returns the all-zeros UUID
    // sentinel. Don't pass that through as an IDFA — it pollutes attribution
    // payloads with junk that downstream MMPs treat as a real id.
    if identifierValue == Self.zeroAdvertisingIdentifier {
      return nil
    }

    return identifierValue.uuidString
    #else
    return nil
    #endif
  }

  // Non-optional construction via `init(uuid:)` — `init(uuidString:)` returns
  // an Optional which would make the equality check silently false-negative
  // (zero-IDFA passes through unfiltered) if the literal ever failed to parse.
  private static let zeroAdvertisingIdentifier = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))

  /// Whether this build/environment can ever produce an AdServices token.
  /// `false` on builds that didn't link AdServices.framework and on debug
  /// simulator runs without `SUPERWALL_MOCK_AD_SERVICES_TOKEN`. Lets the
  /// poster short-circuit before entering its 23s backoff schedule in
  /// development.
  var canProduceAdServicesToken: Bool {
    #if !canImport(AdServices)
    return false
    #else
    #if targetEnvironment(simulator) && DEBUG
    return ProcessInfo.processInfo.environment["SUPERWALL_MOCK_AD_SERVICES_TOKEN"] != nil
    #else
    return true
    #endif
    #endif
  }

  var adServicesToken: String? {
    get async throws {
      #if canImport(AdServices)
      return try await Task<String?, Error>.detached {
        #if targetEnvironment(simulator)
        return Self.simulatorAdServicesToken
        #else
        return try Self.realAdServicesToken
        #endif
      }.value
      #else
      Logger.debug(
        logLevel: .warn,
        scope: .analytics,
        message: "Tried to fetch AdServices attribution token on device without AdServices support."
      )
      return nil
      #endif
    }
  }

  #if canImport(AdServices)
  private static var realAdServicesToken: String? {
    get throws {
      return try AAAttribution.attributionToken()
    }
  }

  #if targetEnvironment(simulator)
  private static var simulatorAdServicesToken: String? {
    #if DEBUG
    if let mockToken = ProcessInfo.processInfo.environment["SUPERWALL_MOCK_AD_SERVICES_TOKEN"] {
      Logger.debug(
        logLevel: .warn,
        scope: .analytics,
        message: "AdServices: mocking token: \(mockToken) for tests."
      )
      return mockToken
    }
    #endif

    Logger.debug(
      logLevel: .warn,
      scope: .analytics,
      message: "AdServices attribution token is not available in the simulator."
    )
    return nil
  }
  #endif
  #endif

  init(
    storage: Storage,
    deviceHelper: DeviceHelper,
    webEntitlementRedeemer: WebEntitlementRedeemer,
    vendorIdProvider: (() -> String)? = nil,
    attStatusProvider: (() -> Int?)? = nil,
    idfaProvider: (() -> String?)? = nil,
    syncUserAttributes: @escaping ([String: Any?]) -> Void = {
      Superwall.shared.setUserAttributes($0)
    }
  ) {
    self.syncUserAttributes = syncUserAttributes
    self.vendorIdProvider = vendorIdProvider
    self.attStatusProvider = attStatusProvider
    self.idfaProvider = idfaProvider
    self.storage = storage
    self.deviceHelper = deviceHelper
    self.webEntitlementRedeemer = webEntitlementRedeemer
    self._integrationAttributes = storage.get(IntegrationAttributes.self) ?? [:]
    if let notification = SystemInfo.applicationDidBecomeActiveNotification {
      activeObserver = NotificationCenter.default.addObserver(
        forName: notification,
        object: nil,
        queue: nil
      ) { [weak self] _ in
        self?.refreshDeviceIdentifiers()
      }
    }
  }

  deinit {
    if let activeObserver {
      NotificationCenter.default.removeObserver(activeObserver)
    }
  }

  func setIntegrationAttribute(
    attribute: IntegrationAttribute,
    value: String?
  ) {
    mergeIntegrationAttributes(attributes: [attribute.description: value])
  }

  func mergeIntegrationAttributes(attributes: [String: String?]) {
    queue.async { [weak self] in
      guard let self = self else { return }

      // Compare after refreshing device data: the provider ID can stay the
      // same while ATT changes or a previously unavailable IDFV appears.
      if self._mergeIntegrationAttributes(attributes: attributes) {
        self._debouncedRedeem()
      }
    }
  }

  private func _debouncedRedeem() {
    // Must be called from self.queue
    // Cancel previous timer (safe to call from any queue)
    redeemTimer?.setEventHandler {}   // break retain cycles
    redeemTimer?.cancel()
    redeemTimer = nil

    // Create timer on separate timerQueue for better timing accuracy
    let timer = DispatchSource.makeTimerSource(queue: timerQueue)
    timer.schedule(deadline: .now() + .milliseconds(500), repeating: .never)
    timer.setEventHandler { [weak self] in
      guard let self else { return }
      // We're on timerQueue, need to sync with main queue for cleanup
      Task {
        await self.webEntitlementRedeemer.redeem(.integrationAttributes)
      }
      // Clean up timer - safe to do from timerQueue
      self.queue.async {
        self.redeemTimer?.setEventHandler {}
        self.redeemTimer?.cancel()
        self.redeemTimer = nil
      }
    }
    redeemTimer = timer
    timer.resume()
  }

  func cancelPendingOperations() {
    // Timer operations are thread-safe, but we synchronize timer reference access
    queue.async {
      self.redeemTimer?.setEventHandler {}
      self.redeemTimer?.cancel()
      self.redeemTimer = nil
    }
  }

  /// - Returns: Whether the integration attributes changed.
  private func _mergeIntegrationAttributes(attributes: [String: String?]) -> Bool {
    var mergedAttributes = _integrationAttributes
    for (key, value) in attributes {
      mergedAttributes[key] = value
    }
    let device = currentDeviceIdentifiers
    for key in DeviceIdentifiers.keys {
      mergedAttributes[key] = device[key]
    }

    // The router reads user attributes, not the integration_attributes event.
    // Explicit nulls clear an IDFA retained from before consent was revoked.
    if device != _lastSyncedDeviceIdentifiers {
      _lastSyncedDeviceIdentifiers = device
      syncUserAttributes(DeviceIdentifiers.userAttributes(for: device))
    }

    guard mergedAttributes != _integrationAttributes else { return false }
    let updatedAttributes = mergedAttributes
    Task {
      let event = InternalSuperwallEvent.IntegrationAttributes(
        audienceFilterParams: updatedAttributes
      )
      await Superwall.shared.track(event)
    }
    storage.save(mergedAttributes, forType: IntegrationAttributes.self)
    _integrationAttributes = mergedAttributes
    if attributes[IntegrationAttribute.appsflyerId.description] != nil {
      deviceHelper.startIPCollectionIfEnabled()
    }
    return true
  }
}

// MARK: - Device identifiers
extension AttributionFetcher {
  /// Forgets what was last synced when a write puts something other than the
  /// SDK's value on one of its keys, so the next merge restores it. Otherwise
  /// an app that removed `idfv` would keep it missing until an identifier
  /// changed. Compares values: the SDK's own sync and the enrichment echo come
  /// back through this setter, and those aren't overwrites.
  func forgetSyncedDeviceIdentifiers(ifChangedBy attributes: [String: Any?]) {
    let touched = attributes.filter { DeviceIdentifiers.keys.contains($0.key) }
    if touched.isEmpty {
      return
    }
    queue.async { [weak self] in
      guard let self,
        let lastSynced = self._lastSyncedDeviceIdentifiers else {
        return
      }
      let isOverwritten = touched.contains { key, value in
        !DeviceIdentifiers.isWhatWasSent(value, forKey: key, in: lastSynced)
      }
      if isOverwritten {
        self._lastSyncedDeviceIdentifiers = nil
      }
    }
  }

  /// The ATT authorization status, or `nil` where the OS has no such concept.
  private var attStatus: Int? {
    if let attStatusProvider {
      return attStatusProvider()
    }
    #if os(iOS) || targetEnvironment(macCatalyst) || os(macOS) || os(visionOS)
    return TrackingManagerProxy().trackingAuthorizationStatus()
    #else
    return nil
    #endif
  }

  private var currentDeviceIdentifiers: [String: String] {
    var attributes: [String: String] = [:]

    #if os(macOS)
    // macOS has no Apple IDFV. The SDK's installation UUID is not an MMP identifier.
    let vendorId = vendorIdProvider?() ?? ""
    #else
    let vendorId = vendorIdProvider?() ?? deviceHelper.vendorId
    #endif
    if !vendorId.isEmpty {
      attributes["idfv"] = vendorId
    }

    if let attStatus {
      attributes["attStatus"] = String(attStatus)
    }

    // Don't gate this on the ATT status. `TrackingManagerProxy` returns
    // `notDetermined` both for a genuine one and for a build where the class
    // can't be found, so the status can't tell those apart. The OS hands back
    // the all-zero id when it doesn't want to share one, and
    // `identifierForAdvertisers` already filters that out.
    attributes["idfa"] = idfaProvider?() ?? identifierForAdvertisers

    return attributes
  }

  func refreshDeviceIdentifiers() {
    queue.async { [weak self] in
      guard let self, !self._integrationAttributes.isEmpty else { return }
      if self._mergeIntegrationAttributes(attributes: [:]) {
        self._debouncedRedeem()
      }
    }
  }

  /// What a reset's new user keeps: device identifiers and install-scoped ids.
  func integrationAttributesKeptAcrossReset() -> [String: Any?] {
    queue.sync {
      guard let (kept, device) = _integrationAttributesKeptAcrossReset() else {
        return [:]
      }
      _resetDeviceIdentifiers = device
      var userAttributes = DeviceIdentifiers.userAttributes(for: device)
      for (key, value) in kept where !DeviceIdentifiers.keys.contains(key) {
        userAttributes[key] = value
      }
      return userAttributes
    }
  }

  /// After a reset, drops the ids that describe the person (see
  /// `isInstallScoped`) and saves the rest to the wiped disk, or a later
  /// consent change would never clear the IDFA. Synchronous, since the redeem
  /// after an identify reads the stored copy.
  func resetIntegrationAttributes() {
    queue.sync {
      let given = _resetDeviceIdentifiers
      _resetDeviceIdentifiers = nil
      if _integrationAttributes.isEmpty {
        return
      }
      guard let (kept, device) = _integrationAttributesKeptAcrossReset() else {
        _integrationAttributes = [:]
        _lastSyncedDeviceIdentifiers = nil
        return
      }
      _integrationAttributes = kept
      _lastSyncedDeviceIdentifiers = device
      storage.save(kept, forType: IntegrationAttributes.self)
      // ATT or the IDFA changed since the new user was given identifiers.
      if device != given {
        syncUserAttributes(DeviceIdentifiers.userAttributes(for: device))
      }
    }
  }

  /// What survives a reset, with fresh device identifiers. Call on `queue`.
  private func _integrationAttributesKeptAcrossReset() -> (kept: [String: String], device: [String: String])? {
    var kept = _integrationAttributes.filter { key, _ in
      DeviceIdentifiers.keys.contains(key)
        || IntegrationAttribute.installScopedKeys.contains(key)
    }
    if kept.isEmpty {
      return nil
    }
    let device = currentDeviceIdentifiers
    for key in DeviceIdentifiers.keys {
      kept[key] = device[key]
    }
    return (kept, device)
  }
}
