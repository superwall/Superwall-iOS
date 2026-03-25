//
//  ModelLoader.swift
//  Superwall
//
//  Created by Yusuf Tör on 04/03/2022.
//
// swiftlint:disable type_body_length

import Foundation
import UIKit
import Combine

class Network {
  private let urlSession: CustomURLSession
  private let factory: ApiFactory
  private let options: SuperwallOptions
  private var applicationStateSubject: CurrentValueSubject<UIApplication.State, Never> = .init(.background)

  init(
    urlSession: CustomURLSession? = nil,
    options: SuperwallOptions,
    factory: ApiFactory
  ) {
    self.options = options
    self.urlSession = urlSession ?? CustomURLSession(factory: factory)
    self.factory = factory

    Task { @MainActor [weak self] in
      self?.applicationStateDidChange()
    }

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(applicationStateDidChange),
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(applicationStateDidChange),
      name: UIApplication.didEnterBackgroundNotification,
      object: nil
    )
  }

  @objc
  @MainActor
  private func applicationStateDidChange() {
    guard let sharedApplication = UIApplication.sharedApplication else {
      return
    }
    applicationStateSubject.send(sharedApplication.applicationState)
  }

  func sendEvents(events: EventsRequest) async {
    do {
      let result = try await urlSession.request(
        .events(eventsRequest: events),
        data: SuperwallRequestData(factory: factory)
      )
      switch result.status {
      case .ok:
        break
      case .partialSuccess:
        Logger.debug(
          logLevel: .warn,
          scope: .network,
          message: "Request had partial success: /events",
          info: ["payload": result.invalidIndexes as Any]
        )
      }
    } catch {
      Logger.debug(
        logLevel: .error,
        scope: .network,
        message: "Request Failed: /events",
        info: ["payload": events],
        error: error
      )
    }
  }

  func getPaywall(
    withId identifier: String? = nil,
    fromPlacement placement: PlacementData? = nil,
    retryCount: Int
  ) async throws -> Paywall {
    do {
      return try await urlSession.request(
        .paywall(
          withIdentifier: identifier,
          fromPlacement: placement,
          retryCount: retryCount,
          appUserId: factory.identityManager.userId,
          apiKey: factory.storage.apiKey,
          config: factory.configManager.config,
          locale: factory.deviceHelper.localeIdentifier
        ),
        data: SuperwallRequestData(factory: factory)
      )
    } catch {
      if identifier == nil {
        Logger.debug(
          logLevel: .error,
          scope: .network,
          message: "Request Failed: /paywall",
          info: [
            "identifier": identifier ?? "none",
            "event": placement.debugDescription
          ],
          error: error
        )
      } else {
        Logger.debug(
          logLevel: .error,
          scope: .network,
          message: "Request Failed: /paywall/:identifier",
          error: error
        )
      }
      throw error
    }
  }

  func getPaywalls() async throws -> [Paywall] {
    do {
      let response = try await urlSession.request(
        .paywalls(),
        data: SuperwallRequestData(
          factory: factory,
          isForDebugging: true
        )
      )
      return response.paywalls
    } catch {
      Logger.debug(
        logLevel: .error,
        scope: .network,
        message: "Request Failed: /paywalls",
        error: error
      )
      throw error
    }
  }

  func getConfig(
    injectedApplicationStatePublisher: (AnyPublisher<UIApplication.State, Never>)? = nil,
    maxRetry: Int? = nil,
    isRetryingCallback: ((Int) -> Void)? = nil,
    timeout: Seconds? = nil
  ) async throws -> Config {
    try await appInForeground(injectedApplicationStatePublisher)

    do {
      let requestId = UUID().uuidString
      var config = try await urlSession.request(
        .config(
          maxRetry: maxRetry ?? options.maxConfigRetryCount,
          apiKey: factory.storage.apiKey,
          timeout: timeout
        ),
        data: SuperwallRequestData(
          factory: factory,
          requestId: requestId
        ),
        isRetryingCallback: isRetryingCallback
      )
      config.requestId = requestId
      return config
    } catch {
      Logger.debug(
        logLevel: .error,
        scope: .network,
        message: "Request Failed: /static_config",
        error: error
      )
      throw error
    }
  }

  @MainActor
  private func appInForeground(
    _ injectedApplicationStatePublisher: (AnyPublisher<UIApplication.State, Never>)? = nil
  ) async throws {
    // Share extensions shouldn't need to wait for the app to be in the foreground to run.
    let isShareExtension = Bundle.main.bundlePath.hasSuffix(".appex")
    if isShareExtension {
      return
    }

    let existingApplicationStatePublisher = self.applicationStateSubject.eraseToAnyPublisher()
    let applicationStatePublisher = injectedApplicationStatePublisher ?? existingApplicationStatePublisher

    // Suspend until app is in foreground.
    try await applicationStatePublisher
      .subscribe(on: DispatchQueue.main)
      .filter { $0 != .background }
      .throwableAsync()
  }

  func getEnrichment(
    request: EnrichmentRequest,
    injectedApplicationStatePublisher: (AnyPublisher<UIApplication.State, Never>)? = nil,
    maxRetry: Int?,
    timeout: Seconds?
  ) async throws -> Enrichment {
    do {
      try await appInForeground(injectedApplicationStatePublisher)

      let start = InternalSuperwallEvent.EnrichmentLoad(state: .start)
      await Superwall.shared.track(start)

      let response = try await urlSession.request(
        .enrichment(
          request: request,
          maxRetry: maxRetry ?? options.maxConfigRetryCount,
          timeout: timeout
        ),
        data: SuperwallRequestData(factory: factory)
      )

      let complete = InternalSuperwallEvent.EnrichmentLoad(
        state: .complete(response)
      )
      await Superwall.shared.track(complete)

      return response
    } catch {
      Logger.debug(
        logLevel: .error,
        scope: .network,
        message: "Request Failed: /enrich",
        error: error
      )

      let fail = InternalSuperwallEvent.EnrichmentLoad(state: .fail)
      await Superwall.shared.track(fail)

      throw error
    }
  }

  func confirmAssignment(_ assignment: Assignment) async -> Assignment {
    let postback = PostbackAssignmentWrapper.create(from: assignment)

    do {
      try await urlSession.request(
        .confirmAssignments(postback),
        data: SuperwallRequestData(factory: factory)
      )
      assignment.markAsSent()
    } catch {
      Logger.debug(
        logLevel: .error,
        scope: .network,
        message: "Request Failed: /confirm_assignments",
        info: ["assignments": postback],
        error: error
      )
    }

    return assignment
  }

  func getAssignments() async throws -> [PostbackAssignment] {
    do {
      let result = try await urlSession.request(
        .assignments(),
        data: SuperwallRequestData(factory: factory)
      )
      return result.assignments
    } catch {
      Logger.debug(
        logLevel: .error,
        scope: .network,
        message: "Request Failed: /assignments",
        error: error
      )
      throw error
    }
  }

  func sendSessionEvents(_ session: SessionEventsRequest) async {
    do {
      let result = try await urlSession.request(
        .sessionEvents(session),
        data: SuperwallRequestData(factory: factory)
      )
      switch result.status {
      case .ok:
        break
      case .partialSuccess:
        Logger.debug(
          logLevel: .warn,
          scope: .network,
          message: "Request had partial success: /session_events",
          info: ["payload": result.invalidIndexes as Any]
        )
      }
    } catch {
      Logger.debug(
        logLevel: .error,
        scope: .network,
        message: "Request Failed: /session_events",
        info: ["payload": session],
        error: error
      )
    }
  }

  func sendToken(_ token: String) async -> [String: Any]? {
    do {
      let jsonDict = try await urlSession.request(
        .adServices(token: token),
        data: SuperwallRequestData(factory: factory)
      ).attribution
      return convertJSONToDictionary(attribution: jsonDict)
    } catch {
      Logger.debug(
        logLevel: .error,
        scope: .network,
        message: "Request Failed: /apple-ad-services/token",
        info: ["payload": token],
        error: error
      )
      return nil
    }
  }

  private func mergeMMPAcquisitionAttributesIfNeeded(
    _ acquisitionAttributes: [String: JSON],
    identityManager: IdentityManager
  ) {
    let attributes = convertJSONToDictionary(attribution: acquisitionAttributes)
    guard !attributes.isEmpty else {
      return
    }

    let currentAttributes = identityManager.userAttributes
    let hasChanges = attributes.contains { key, value in
      guard let currentValue = currentAttributes[key] else {
        return true
      }

      return JSON(currentValue).rawString([:]) != JSON(value).rawString([:])
    }

    guard hasChanges else {
      return
    }

    Superwall.shared.setUserAttributes(attributes)
  }

  func redeemEntitlements(request: RedeemRequest) async throws -> RedeemResponse {
    return try await urlSession.request(
      .redeem(request: request),
      data: SuperwallRequestData(factory: factory)
    )
  }

  func pollRedemptionResult(request: PollRedemptionResultRequest) async throws -> RedeemResponse {
    return try await urlSession.request(
      .pollRedemptionResult(request: request),
      data: SuperwallRequestData(factory: factory)
    )
  }

  func getEntitlements(
    appUserId: String?,
    deviceId: String
  ) async throws -> EntitlementsResponse {
    return try await urlSession.request(
      .entitlements(
        appUserId: appUserId,
        deviceId: deviceId
      ),
      data: SuperwallRequestData(factory: factory)
    )
  }

  func getIntroOfferToken(
    productIds: [String],
    appTransactionId: String,
    allowIntroductoryOffer: Bool
  ) async throws -> [String: IntroOfferToken] {
    return try await urlSession.request(
      .getIntroOfferToken(
        productIds: productIds,
        appTransactionId: appTransactionId,
        allowIntroductoryOffer: allowIntroductoryOffer
      ),
      data: SuperwallRequestData(factory: factory)
    ).tokensByProductId
  }

  /// Fetches all products from the subscriptions API.
  /// The application is inferred from the SDK's public API key.
  ///
  /// - Returns: A response containing all products for this application.
  func getSuperwallProducts() async throws -> SuperwallProductsResponse {
    do {
      let response: SuperwallProductsResponse = try await urlSession.request(
        .superwallProducts(),
        data: SuperwallRequestData(factory: factory)
      )
      return response
    } catch {
      Logger.debug(
        logLevel: .error,
        scope: .network,
        message: "Request Failed: /v1/products",
        error: error
      )
      throw error
    }
  }

  func matchMMPInstall(idfa: String?) async -> Bool {
    guard
      let deviceHelper = factory.deviceHelper,
      let identityManager = factory.identityManager
    else {
      Logger.debug(
        logLevel: .warn,
        scope: .network,
        message: "Skipped: /api/match",
        info: ["reason": "Dependencies unavailable"]
      )
      return false
    }

    let rawMetadata = [
      "preferredLocaleIdentifier": deviceHelper.preferredLocaleIdentifier,
      "preferredLanguageCode": deviceHelper.preferredLanguageCode,
      "preferredRegionCode": deviceHelper.preferredRegionCode,
      "interfaceType": deviceHelper.interfaceType,
      "appInstalledAt": deviceHelper.appInstalledAtString,
      "radioType": deviceHelper.radioType,
      "isLowPowerModeEnabled": deviceHelper.isLowPowerModeEnabled,
      "isSandbox": deviceHelper.isSandbox,
      "platformWrapper": deviceHelper.platformWrapper,
      "platformWrapperVersion": deviceHelper.platformWrapperVersion
    ]

    let metadata = rawMetadata.reduce(into: [String: String]()) { result, entry in
      guard let value = entry.value, !value.isEmpty else {
        return
      }
      result[entry.key] = value
    }

    let vendorId = deviceHelper.vendorId

    let request = MMPMatchRequest(
      platform: "ios",
      appUserId: identityManager.appUserId,
      deviceId: factory.makeDeviceId(),
      vendorId: vendorId,
      idfa: idfa,
      idfv: vendorId,
      appVersion: deviceHelper.appVersion,
      sdkVersion: sdkVersion,
      osVersion: deviceHelper.osVersion,
      deviceModel: deviceHelper.model,
      deviceLocale: deviceHelper.localeIdentifier,
      deviceLanguageCode: deviceHelper.languageCode,
      bundleId: deviceHelper.bundleId,
      clientTimestamp: Date().isoString,
      metadata: metadata
    )

    do {
      let response: MMPMatchResponse = try await urlSession.request(
        .matchMMPInstall(request: request),
        data: SuperwallRequestData(factory: factory)
      )

      Logger.debug(
        logLevel: .debug,
        scope: .network,
        message: "Request Completed: /api/match",
        info: [
          "matched": response.matched,
          "confidence": response.confidence as Any,
          "link_id": response.linkId as Any,
        ]
      )

      if let acquisitionAttributes = response.acquisitionAttributes {
        mergeMMPAcquisitionAttributesIfNeeded(
          acquisitionAttributes,
          identityManager: identityManager
        )
      }

      await Superwall.shared.track(
        InternalSuperwallEvent.AttributionMatch(
          info: AttributionMatchInfo(
            provider: .mmp,
            matched: response.matched,
            source: response.acquisitionAttributes?["acquisition_source"]?.string ?? response.network,
            confidence: response.confidence,
            matchScore: response.matchScore,
            reason: response.breakdown?["reason"]?.string
          )
        )
      )

      return true
    } catch {
      Logger.debug(
        logLevel: .error,
        scope: .network,
        message: "Request Failed: /api/match",
        info: ["payload": request],
        error: error
      )

      await Superwall.shared.track(
        InternalSuperwallEvent.AttributionMatch(
          info: AttributionMatchInfo(
            provider: .mmp,
            matched: false,
            reason: "request_failed"
          )
        )
      )

      return false
    }
  }
}
