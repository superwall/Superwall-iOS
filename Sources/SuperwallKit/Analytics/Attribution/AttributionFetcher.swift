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
  private let syncDeviceAttributes: ([String: Any?]) -> Void
  private var _integrationAttributes: [String: String] = [:]

  /// The last device snapshot handed to `syncDeviceAttributes`. Only a change
  /// is worth syncing: every sync costs a `user_attributes` event, a delegate
  /// callback, a Core Data row and a re-encode of the whole attribute dict.
  private var _lastSyncedDeviceAttributes: [String: String]?

  /// The device keys the SDK owns in both integration and user attributes.
  private static let deviceAttributeKeys = ["idfa", "idfv", "attStatus"]
  private unowned let storage: Storage
  private unowned let webEntitlementRedeemer: WebEntitlementRedeemer
  private unowned let deviceHelper: DeviceHelper

  var identifierForAdvertisers: String? {
    // should match available platforms here:
    // https://developer.apple.com/documentation/adsupport/asidentifiermanager/1614151-advertisingidentifier
    #if os(iOS) || os(tvOS) || os(macOS) || os(visionOS)
    if #available(macCatalyst 13.1, macOS 10.14, *) {
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
    }
    #endif
    return nil
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

  // should match OS availability in https://developer.apple.com/documentation/ad_services
  @available(iOS 14.3, tvOS 14.3, macOS 11.1, watchOS 6.2, macCatalyst 14.3, *)
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
  @available(iOS 14.3, macOS 11.1, macCatalyst 14.3, *)
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
    syncDeviceAttributes: @escaping ([String: Any?]) -> Void = {
      Superwall.shared.setUserAttributes($0)
    }
  ) {
    self.syncDeviceAttributes = syncDeviceAttributes
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
        self?.refreshDeviceAttributes()
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
    let device = currentDeviceAttributes
    for key in Self.deviceAttributeKeys {
      mergedAttributes[key] = device[key]
    }

    // The router reads user attributes, not the integration_attributes event.
    // Explicit nulls clear an IDFA retained from before consent was revoked.
    if device != _lastSyncedDeviceAttributes {
      _lastSyncedDeviceAttributes = device
      var userAttributes: [String: Any?] = [:]
      for key in Self.deviceAttributeKeys {
        userAttributes[key] = device[key].map { $0 as Any } ?? NSNull()
      }
      syncDeviceAttributes(userAttributes)
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
    return true
  }
}

// MARK: - Device attributes
extension AttributionFetcher {
  /// The ATT authorization status, or `nil` where the OS has no such concept.
  private var attStatus: Int? {
    if let attStatusProvider {
      return attStatusProvider()
    }
    #if os(iOS) || targetEnvironment(macCatalyst) || os(tvOS) || os(macOS) || os(visionOS)
    if #available(iOS 14, macCatalyst 14, tvOS 14, macOS 11, *) {
      return TrackingManagerProxy().trackingAuthorizationStatus()
    }
    #endif
    return nil
  }

  private var currentDeviceAttributes: [String: String] {
    var attributes: [String: String] = [:]

    let vendorId = vendorIdProvider?() ?? deviceHelper.vendorId
    if !vendorId.isEmpty {
      attributes["idfv"] = vendorId
    }

    if let attStatus {
      attributes["attStatus"] = String(attStatus)
    }

    // Don't gate this on the ATT status. Before iOS 14.5 the IDFA is available
    // while ATT still reads `notDetermined`, and `TrackingManagerProxy` returns
    // `notDetermined` both for a genuine one and for a build where the class
    // can't be found, so the status can't tell those apart. The OS hands back
    // the all-zero id when it doesn't want to share one, and
    // `identifierForAdvertisers` already filters that out.
    attributes["idfa"] = idfaProvider?() ?? identifierForAdvertisers

    return attributes
  }

  func refreshDeviceAttributes() {
    queue.async { [weak self] in
      guard let self, !self._integrationAttributes.isEmpty else { return }
      if self._mergeIntegrationAttributes(attributes: [:]) {
        self._debouncedRedeem()
      }
    }
  }

  /// Re-scopes the integration attributes for the user that `reset()` just
  /// created.
  ///
  /// Identifiers that describe the person — see `isInstallScoped` — belong to
  /// whoever was just signed out, so they go. The install-scoped ones describe
  /// the same device either way and stay, along with the device identifiers.
  ///
  /// A reset clears the user's attributes and deletes the stored copy of the
  /// integration attributes, which live in the user-specific directory, while
  /// the in-memory copy outlives it. So write what's kept back to disk and hand
  /// all of it — not just what changed — to the new user, who has none of it.
  /// Without the file the next cold launch would start empty and the activation
  /// refresh would never run again, so a later consent change would never clear
  /// the IDFA.
  ///
  /// Runs synchronously. `identify` redeems for the new user immediately after
  /// the reset, and that request reads the stored attributes rather than this
  /// object, so they have to be settled before this returns. No redeem is
  /// scheduled from here; the identity redeems on its own.
  func resetIntegrationAttributes() {
    queue.sync {
      if _integrationAttributes.isEmpty {
        return
      }
      var kept = _integrationAttributes.filter { key, _ in
        Self.deviceAttributeKeys.contains(key)
          || IntegrationAttribute.installScopedKeys.contains(key)
      }
      if kept.isEmpty {
        _integrationAttributes = [:]
        _lastSyncedDeviceAttributes = nil
        return
      }

      let device = currentDeviceAttributes
      for key in Self.deviceAttributeKeys {
        kept[key] = device[key]
      }
      _integrationAttributes = kept
      _lastSyncedDeviceAttributes = device
      storage.save(kept, forType: IntegrationAttributes.self)

      var userAttributes: [String: Any?] = [:]
      for (key, value) in kept where !Self.deviceAttributeKeys.contains(key) {
        userAttributes[key] = value
      }
      for key in Self.deviceAttributeKeys {
        userAttributes[key] = device[key].map { $0 as Any } ?? NSNull()
      }
      syncDeviceAttributes(userAttributes)
    }
  }
}
