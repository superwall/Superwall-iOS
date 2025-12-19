//
//  File.swift
//
//
//  Created by Yusuf Tör on 20/04/2022.
//
// swiftlint:disable type_body_length nesting file_length type_body_length

import Foundation
import StoreKit

protocol TrackableSuperwallEvent: Trackable {
  /// The ``SuperwallEvent`` to be tracked by this placement.
  var superwallEvent: SuperwallEvent { get }
}

extension TrackableSuperwallEvent {
  var rawName: String {
    return String(describing: superwallEvent)
  }

  var canImplicitlyTriggerPaywall: Bool {
    return superwallEvent.canImplicitlyTriggerPaywall
  }
}

/// These are events that tracked internally and sent back to the user via the delegate.
enum InternalSuperwallEvent {
  struct AppOpen: TrackableSuperwallEvent {
    let superwallEvent: SuperwallEvent = .appOpen
    var audienceFilterParams: [String: Any] = [:]
    func getSuperwallParameters() async -> [String: Any] { [:] }
  }

  struct AppInstall: TrackableSuperwallEvent {
    let superwallEvent: SuperwallEvent = .appInstall
    let appInstalledAtString: String
    let hasExternalPurchaseController: Bool
    var audienceFilterParams: [String: Any] = [:]
    func getSuperwallParameters() async -> [String: Any] {
      return [
        "application_installed_at": appInstalledAtString,
        "using_purchase_controller": hasExternalPurchaseController
      ]
    }
  }

  struct TouchesBegan: TrackableSuperwallEvent {
    let superwallEvent: SuperwallEvent = .touchesBegan
    var audienceFilterParams: [String: Any] = [:]
    func getSuperwallParameters() async -> [String: Any] { [:] }
  }

  struct SurveyClose: TrackableSuperwallEvent {
    let superwallEvent: SuperwallEvent = .surveyClose
    var audienceFilterParams: [String: Any] = [:]
    func getSuperwallParameters() async -> [String: Any] { [:] }
  }

  struct SurveyResponse: TrackableSuperwallEvent {
    var superwallEvent: SuperwallEvent {
      return .surveyResponse(
        survey: survey,
        selectedOption: selectedOption,
        customResponse: customResponse,
        paywallInfo: paywallInfo
      )
    }
    var audienceFilterParams: [String: Any] {
      let output = paywallInfo.audienceFilterParams()
      return output + [
        "survey_selected_option_title": selectedOption.title,
        "survey_custom_response": customResponse as Any
      ]
    }
    let survey: Survey
    let selectedOption: SurveyOption
    let customResponse: String?
    let paywallInfo: PaywallInfo

    func getSuperwallParameters() async -> [String: Any] {
      let params: [String: Any] = [
        "survey_id": survey.id,
        "survey_assignment_key": survey.assignmentKey,
        "survey_selected_option_id": selectedOption.id
      ]

      return await paywallInfo.placementParams(otherParams: params)
    }
  }

  struct AppLaunch: TrackableSuperwallEvent {
    let superwallEvent: SuperwallEvent = .appLaunch
    var audienceFilterParams: [String: Any] = [:]
    func getSuperwallParameters() async -> [String: Any] { [:] }
  }

  struct UserAttributes: TrackableSuperwallEvent {
    let appInstalledAtString: String
    var superwallEvent: SuperwallEvent {
      return .userAttributes(audienceFilterParams)
    }
    func getSuperwallParameters() async -> [String: Any] {
      return [
        "application_installed_at": appInstalledAtString
      ]
    }
    var audienceFilterParams: [String: Any] = [:]
  }

  struct IntegrationAttributes: TrackableSuperwallEvent {
    var superwallEvent: SuperwallEvent {
      return .integrationAttributes(audienceFilterParams)
    }
    func getSuperwallParameters() async -> [String: Any] {
      return [:]
    }
    var audienceFilterParams: [String: Any] = [:]
  }

  struct IdentityAlias: TrackableSuperwallEvent {
    let superwallEvent: SuperwallEvent = .identityAlias
    var audienceFilterParams: [String: Any] = [:]
    func getSuperwallParameters() async -> [String: Any] { [:] }
  }

  struct DeepLink: TrackableSuperwallEvent {
    var superwallEvent: SuperwallEvent {
      .deepLink(url: url)
    }
    let url: URL
    private var parameters: [String: Any] {
      [
        "url": url.absoluteString,
        "path": url.path,
        "pathExtension": url.pathExtension,
        "lastPathComponent": url.lastPathComponent,
        "host": url.host ?? "",
        "query": url.query ?? "",
        "fragment": url.fragment ?? ""
      ]
    }

    func getSuperwallParameters() async -> [String: Any] {
      return parameters
    }

    var audienceFilterParams: [String: Any] {
      var parameters: [String: Any] = parameters
      guard
        let urlComponents = URLComponents(
          url: url,
          resolvingAgainstBaseURL: false
        )
      else {
        return parameters
      }
      guard let queryItems = urlComponents.queryItems else {
        return parameters
      }

      for queryItem in queryItems {
        guard
          !queryItem.name.isEmpty,
          let value = queryItem.value,
          !value.isEmpty
        else {
          continue
        }
        let name = queryItem.name
        let lowerCaseValue = value.lowercased()
        if lowerCaseValue == "true" {
          parameters[name] = true
        } else if lowerCaseValue == "false" {
          parameters[name] = false
        } else if let int = Int(value) {
          parameters[name] = int
        } else if let double = Double(value) {
          parameters[name] = double
        } else {
          parameters[name] = value
        }
      }
      return parameters
    }
  }

  struct FirstSeen: TrackableSuperwallEvent {
    let superwallEvent: SuperwallEvent = .firstSeen
    var audienceFilterParams: [String: Any] = [:]
    func getSuperwallParameters() async -> [String: Any] { [:] }
  }

  struct Reset: TrackableSuperwallEvent {
    let superwallEvent: SuperwallEvent = .reset
    var audienceFilterParams: [String: Any] = [:]
    func getSuperwallParameters() async -> [String: Any] { [:] }
  }

  struct AppClose: TrackableSuperwallEvent {
    let superwallEvent: SuperwallEvent = .appClose
    var audienceFilterParams: [String: Any] = [:]
    func getSuperwallParameters() async -> [String: Any] { [:] }
  }

  struct SessionStart: TrackableSuperwallEvent {
    let superwallEvent: SuperwallEvent = .sessionStart
    var audienceFilterParams: [String: Any] = [:]
    func getSuperwallParameters() async -> [String: Any] { [:] }
  }

  struct ConfigAttributes: TrackableSuperwallEvent {
    let superwallEvent: SuperwallEvent = .configAttributes
    let options: SuperwallOptions
    let hasExternalPurchaseController: Bool
    let hasDelegate: Bool

    var audienceFilterParams: [String: Any] = [:]
    func getSuperwallParameters() async -> [String: Any] {
      var params = options.toDictionary()
      params += [
        "using_purchase_controller": hasExternalPurchaseController,
        "has_delegate": hasDelegate
      ]
      return params
    }
  }

  struct DeviceAttributes: TrackableSuperwallEvent {
    var superwallEvent: SuperwallEvent {
      return .deviceAttributes(attributes: deviceAttributes)
    }
    let deviceAttributes: [String: Any]

    var audienceFilterParams: [String: Any] = [:]
    func getSuperwallParameters() async -> [String: Any] {
      return deviceAttributes
    }
  }

  struct PaywallLoad: TrackableSuperwallEvent {
    enum State {
      case start
      case notFound
      case fail
      case complete(paywallInfo: PaywallInfo)
    }
    let state: State

    var superwallEvent: SuperwallEvent {
      switch state {
      case .start:
        return .paywallResponseLoadStart(triggeredPlacementName: placementData?.name)
      case .notFound:
        return .paywallResponseLoadNotFound(triggeredPlacementName: placementData?.name)
      case .fail:
        return .paywallResponseLoadFail(triggeredPlacementName: placementData?.name)
      case .complete(let paywallInfo):
        return .paywallResponseLoadComplete(
          triggeredPlacementName: placementData?.name,
          paywallInfo: paywallInfo
        )
      }
    }
    let placementData: PlacementData?
    var audienceFilterParams: [String: Any] {
      switch state {
      case .complete(let paywallInfo):
        return paywallInfo.audienceFilterParams()
      default:
        return [:]
      }
    }

    func getSuperwallParameters() async -> [String: Any] {
      let fromPlacement = placementData != nil
      let params: [String: Any] = [
        "is_triggered_from_event": fromPlacement
      ]

      switch state {
      case .start,
        .notFound,
        .fail:
        return params
      case .complete(let paywallInfo):
        return await paywallInfo.placementParams(otherParams: params)
      }
    }
  }

  struct SubscriptionStatusDidChange: TrackableSuperwallEvent {
    let superwallEvent: SuperwallEvent = .subscriptionStatusDidChange
    let status: SubscriptionStatus
    var audienceFilterParams: [String: Any] = [:]
    func getSuperwallParameters() async -> [String: Any] {
      var params: [String: Any] = [
        "status": status.description
      ]
      if case let .active(entitlements) = status {
        params += [
          "active_entitlement_ids": entitlements.map(\.id).joined()
        ]
      }
      return params
    }
  }

  struct CustomerInfoDidChange: TrackableSuperwallEvent {
    let superwallEvent: SuperwallEvent = .customerInfoDidChange
    var audienceFilterParams: [String: Any] = [:]
    let fromCustomerInfo: CustomerInfo
    let toCustomerInfo: CustomerInfo

    private struct EntitlementsSnapshot: Encodable {
      let entitlements: [Entitlement]
      let isPlaceholder: Bool
    }

    func getSuperwallParameters() async -> [String: Any] {
      let encoder = JSONEncoder()
      encoder.dateEncodingStrategy = .iso8601

      var fromJson = "{}"
      var toJson = "{}"

      let fromSnapshot = EntitlementsSnapshot(
        entitlements: fromCustomerInfo.entitlements,
        isPlaceholder: fromCustomerInfo.isPlaceholder
      )
      let toSnapshot = EntitlementsSnapshot(
        entitlements: toCustomerInfo.entitlements,
        isPlaceholder: toCustomerInfo.isPlaceholder
      )

      if let data = try? encoder.encode(fromSnapshot),
        let jsonString = String(data: data, encoding: .utf8) {
        fromJson = jsonString
      }

      if let data = try? encoder.encode(toSnapshot),
        let jsonString = String(data: data, encoding: .utf8) {
        toJson = jsonString
      }

      return [
        "from": fromJson,
        "to": toJson
      ]
    }
  }

  struct TriggerFire: TrackableSuperwallEvent {
    let triggerResult: InternalTriggerResult
    var superwallEvent: SuperwallEvent {
      return .triggerFire(
        placementName: triggerName,
        result: triggerResult.toPublicType()
      )
    }
    let triggerName: String
    var audienceFilterParams: [String: Any] = [:]

    func getSuperwallParameters() async -> [String: Any] {
      var params: [String: Any] = [
        "trigger_name": triggerName
      ]

      switch triggerResult {
      case .noAudienceMatch(let unmatchedAudiences):
        params += [
          "result": "no_rule_match"
        ]
        for unmatchedAudience in unmatchedAudiences {
          params["unmatched_audience_\(unmatchedAudience.experimentId)"] =
            unmatchedAudience.source.rawValue
        }
        return params
      case .holdout(let experiment):
        return params + [
          "variant_id": experiment.variant.id as Any,
          "experiment_id": experiment.id as Any,
          "result": "holdout"
        ]
      case let .paywall(experiment):
        return params + [
          "variant_id": experiment.variant.id as Any,
          "experiment_id": experiment.id as Any,
          "paywall_identifier": experiment.variant.paywallId as Any,
          "result": "present"
        ]
      case .placementNotFound:
        return params + [
          "result": "eventNotFound"
        ]
      case .error:
        return params + [
          "result": "error"
        ]
      }
    }
  }

  struct PresentationRequest: TrackableSuperwallEvent {
    let placementData: PlacementData?
    let type: PresentationRequestType
    let status: PaywallPresentationRequestStatus
    let statusReason: PaywallPresentationRequestStatusReason?
    let factory:
      AudienceFilterAttributesFactory & FeatureFlagsFactory & ComputedPropertyRequestsFactory

    var superwallEvent: SuperwallEvent {
      return .paywallPresentationRequest(
        status: status,
        reason: statusReason
      )
    }
    var audienceFilterParams: [String: Any] = [:]
    func getSuperwallParameters() async -> [String: Any] {
      var params = [
        "source_event_name": placementData?.name ?? "",
        "pipeline_type": type.description,
        "status": status.rawValue,
        "status_reason": statusReason?.description ?? ""
      ]

      if let featureFlags = factory.makeFeatureFlags(),
        featureFlags.enableExpressionParameters {
        let computedPropertyRequests = factory.makeComputedPropertyRequests()
        let audienceFilters = await factory.makeAudienceFilterAttributes(
          forPlacement: placementData,
          withComputedProperties: computedPropertyRequests
        )

        if let jsonData = try? JSONSerialization.data(withJSONObject: audienceFilters),
          let decoded = String(data: jsonData, encoding: .utf8) {
          params += [
            "expression_params": decoded
          ]
        }
      }

      return params
    }
  }

  struct PaywallOpen: TrackableSuperwallEvent {
    var superwallEvent: SuperwallEvent {
      return .paywallOpen(paywallInfo: paywallInfo)
    }
    let paywallInfo: PaywallInfo
    let demandScore: Int?
    let demandTier: String?

    func getSuperwallParameters() async -> [String: Any] {
      var params = await paywallInfo.placementParams()
      if let demandScore = demandScore {
        params["attr_demandScore"] = demandScore
      }
      if let demandTier = demandTier {
        params["attr_demandTier"] = demandTier
      }
      params["user_attributes"] = Superwall.shared.userAttributes
      return params
    }
    var audienceFilterParams: [String: Any] {
      return paywallInfo.audienceFilterParams()
    }
  }

  struct PaywallClose: TrackableSuperwallEvent {
    var superwallEvent: SuperwallEvent {
      return .paywallClose(paywallInfo: paywallInfo)
    }
    let paywallInfo: PaywallInfo
    let surveyPresentationResult: SurveyPresentationResult

    func getSuperwallParameters() async -> [String: Any] {
      var params: [String: Any] = [
        "survey_attached": paywallInfo.surveys.isEmpty ? false : true
      ]

      if surveyPresentationResult != .noShow {
        params["survey_presentation"] = surveyPresentationResult.rawValue
      }

      let placementParams = await paywallInfo.placementParams()
      params += placementParams
      return params
    }
    var audienceFilterParams: [String: Any] {
      return paywallInfo.audienceFilterParams()
    }
  }

  struct PaywallDecline: TrackableSuperwallEvent {
    var superwallEvent: SuperwallEvent {
      return .paywallDecline(paywallInfo: paywallInfo)
    }
    let paywallInfo: PaywallInfo
    func getSuperwallParameters() async -> [String: Any] {
      return await paywallInfo.placementParams()
    }
    var audienceFilterParams: [String: Any] {
      return paywallInfo.audienceFilterParams()
    }
  }

  struct CustomPlacement: TrackableSuperwallEvent {
    var superwallEvent: SuperwallEvent {
      return .customPlacement(
        name: name,
        params: params,
        paywallInfo: paywallInfo
      )
    }
    var rawName: String {
      return name
    }
    let paywallInfo: PaywallInfo
    let name: String
    let params: [String: Any]

    func getSuperwallParameters() async -> [String: Any] {
      var placementParams = await paywallInfo.placementParams()
      placementParams += params
      placementParams += [
        "name": name
      ]
      return placementParams
    }
    var audienceFilterParams: [String: Any] {
      var customParams = paywallInfo.audienceFilterParams()
      customParams += params
      return customParams
    }
  }

  struct Restore: TrackableSuperwallEvent {
    enum State {
      case start
      case fail(String)
      case complete
    }
    let state: State
    let paywallInfo: PaywallInfo

    var superwallEvent: SuperwallEvent {
      switch state {
      case .start:
        return .restoreStart
      case .fail(let message):
        return .restoreFail(message: message)
      case .complete:
        return .restoreComplete
      }
    }
    var audienceFilterParams: [String: Any] {
      return paywallInfo.audienceFilterParams()
    }
    func getSuperwallParameters() async -> [String: Any] {
      var placementParams = await paywallInfo.placementParams()
      if case .fail(let message) = state {
        placementParams["error_message"] = message
      }
      return placementParams
    }
  }

  struct Transaction: TrackableSuperwallEvent {
    enum State {
      case start(StoreProduct)
      case fail(TransactionError)
      case abandon(StoreProduct?)
      case complete(StoreProduct, StoreTransaction?, TransactionType)
      case restore(RestoreType)
      case timeout
    }
    let state: State

    var superwallEvent: SuperwallEvent {
      switch state {
      case .start(let product):
        return .transactionStart(
          product: product,
          paywallInfo: paywallInfo
        )
      case .fail(let error):
        return .transactionFail(
          error: error,
          paywallInfo: paywallInfo
        )
      case .abandon(let product):
        return .transactionAbandon(
          product: product ?? .blank(),
          paywallInfo: paywallInfo
        )
      case let .complete(product, model, type):
        return .transactionComplete(
          transaction: model,
          product: product,
          type: type,
          paywallInfo: paywallInfo
        )
      case .restore(let restoreType):
        return .transactionRestore(
          restoreType: restoreType,
          paywallInfo: paywallInfo
        )
      case .timeout:
        return .transactionTimeout(paywallInfo: paywallInfo)
      }
    }
    enum Source: String {
      case `internal` = "SUPERWALL"
      case external = "APP"
    }
    let paywallInfo: PaywallInfo
    let product: StoreProduct?
    let transaction: StoreTransaction?
    let source: Source
    let isObserved: Bool
    let storeKitVersion: SuperwallOptions.StoreKitVersion?
    var store: ProductStore = .appStore
    var demandScore: Int?
    var demandTier: String?

    var canImplicitlyTriggerPaywall: Bool {
      if isObserved {
        return false
      }
      return superwallEvent.canImplicitlyTriggerPaywall
    }

    var audienceFilterParams: [String: Any] {
      switch state {
      case .abandon(let product):
        var params = paywallInfo.audienceFilterParams()
        if let product = product {
          params["abandoned_product_id"] = product.productIdentifier
        }
        return params
      default:
        return paywallInfo.audienceFilterParams()
      }
    }

    func getSuperwallParameters() async -> [String: Any] {
      var storefrontCountryCode = ""
      var storefrontId = ""
      if #available(iOS 15.0, *) {
        storefrontCountryCode = await Storefront.current?.countryCode ?? ""
        storefrontId = await Storefront.current?.id ?? ""
      }
      var placementParams: [String: Any] = [
        "store": store.description,
        "source": source.rawValue
      ]
      if let storeKitVersion = storeKitVersion {
        placementParams["storekit_version"] = storeKitVersion.description
      }

      switch state {
      case .restore:
        placementParams += await paywallInfo.placementParams(forProduct: product)
        if let transactionDict = transaction?.dictionary(withSnakeCase: true) {
          placementParams += transactionDict
        }
        placementParams["restore_via_purchase_attempt"] = transaction != nil
        return placementParams
      case .complete(_, _, let type):
        placementParams += [
          "storefront_countryCode": storefrontCountryCode,
          "storefront_id": storefrontId,
          "transaction_type": type.description
        ]
        if let demandScore = demandScore {
          placementParams["attr_demandScore"] = demandScore
        }
        if let demandTier = demandTier {
          placementParams["attr_demandTier"] = demandTier
        }
        placementParams["user_attributes"] = Superwall.shared.userAttributes
        fallthrough
      case .start,
        .abandon,
        .timeout:
        placementParams += await paywallInfo.placementParams(forProduct: product)
        if let transactionDict = transaction?.dictionary(withSnakeCase: true) {
          placementParams += transactionDict
        }
        return placementParams
      case .fail(let error):
        switch error {
        case .failure(let message, _),
          .pending(let message):
          let paywallInfoParams = await paywallInfo.placementParams(
            forProduct: product,
            otherParams: ["message": message]
          )
          return placementParams + paywallInfoParams
        }
      }
    }
  }

  struct SubscriptionStart: TrackableSuperwallEvent {
    var superwallEvent: SuperwallEvent {
      return .subscriptionStart(product: product, paywallInfo: paywallInfo)
    }
    let paywallInfo: PaywallInfo
    let product: StoreProduct
    let transaction: StoreTransaction?
    var audienceFilterParams: [String: Any] {
      return paywallInfo.audienceFilterParams()
    }

    func getSuperwallParameters() async -> [String: Any] {
      var params = await paywallInfo.placementParams(forProduct: product)
      if let transactionDict = transaction?.dictionary(withSnakeCase: true) {
        params += transactionDict
      }
      return params
    }
  }

  struct ConfirmAllAssignments: TrackableSuperwallEvent {
    let superwallEvent: SuperwallEvent = .confirmAllAssignments
    let audienceFilterParams: [String: Any] = [:]
    func getSuperwallParameters() async -> [String: Any] { [:] }
  }

  struct FreeTrialStart: TrackableSuperwallEvent {
    var superwallEvent: SuperwallEvent {
      return .freeTrialStart(
        product: product,
        paywallInfo: paywallInfo
      )
    }
    let paywallInfo: PaywallInfo
    let product: StoreProduct
    let transaction: StoreTransaction?
    var audienceFilterParams: [String: Any] {
      return paywallInfo.audienceFilterParams()
    }

    func getSuperwallParameters() async -> [String: Any] {
      var params = await paywallInfo.placementParams(forProduct: product)
      if let transactionDict = transaction?.dictionary(withSnakeCase: true) {
        params += transactionDict
      }
      return params
    }
  }

  struct NonRecurringProductPurchase: TrackableSuperwallEvent {
    var superwallEvent: SuperwallEvent {
      return .nonRecurringProductPurchase(
        product: .init(product: product),
        paywallInfo: paywallInfo
      )
    }
    let paywallInfo: PaywallInfo
    let product: StoreProduct
    let transaction: StoreTransaction?
    var audienceFilterParams: [String: Any] {
      return paywallInfo.audienceFilterParams()
    }

    func getSuperwallParameters() async -> [String: Any] {
      var params = await paywallInfo.placementParams(forProduct: product)
      if let transactionDict = transaction?.dictionary(withSnakeCase: true) {
        params += transactionDict
      }
      return params
    }
  }

  struct PaywallWebviewLoad: TrackableSuperwallEvent {
    enum State {
      case start
      case fail(Error, [URL])
      case timeout
      case complete
      case fallback
      case processTerminated
    }
    let state: State

    var superwallEvent: SuperwallEvent {
      switch state {
      case .start:
        return .paywallWebviewLoadStart(paywallInfo: paywallInfo)
      case .fail:
        return .paywallWebviewLoadFail(paywallInfo: paywallInfo)
      case .timeout:
        return .paywallWebviewLoadTimeout(paywallInfo: paywallInfo)
      case .complete:
        return .paywallWebviewLoadComplete(paywallInfo: paywallInfo)
      case .fallback:
        return .paywallWebviewLoadFallback(paywallInfo: paywallInfo)
      case .processTerminated:
        return .paywallWebviewProcessTerminated(paywallInfo: paywallInfo)
      }
    }
    let paywallInfo: PaywallInfo

    func getSuperwallParameters() async -> [String: Any] {
      var placementParams = await paywallInfo.placementParams()
      if case .fail(let error, let urls) = state {
        placementParams["error_message"] = error.safeLocalizedDescription
        for (index, url) in urls.enumerated() {
          placementParams["url_\(index)"] = url.absoluteString
        }
      }
      return placementParams
    }
    var audienceFilterParams: [String: Any] {
      return paywallInfo.audienceFilterParams()
    }
  }

  struct PaywallProductsLoad: TrackableSuperwallEvent {
    enum State {
      case start
      case fail(Error)
      case complete
      case retry(Int)
      case missingProducts(Set<String>)
    }
    let state: State
    var audienceFilterParams: [String: Any] {
      return paywallInfo.audienceFilterParams()
    }

    var superwallEvent: SuperwallEvent {
      switch state {
      case .start:
        return .paywallProductsLoadStart(
          triggeredPlacementName: placementData?.name, paywallInfo: paywallInfo)
      case .fail:
        return .paywallProductsLoadFail(
          triggeredPlacementName: placementData?.name, paywallInfo: paywallInfo)
      case .complete:
        return .paywallProductsLoadComplete(triggeredPlacementName: placementData?.name)
      case .retry(let attempt):
        return .paywallProductsLoadRetry(
          triggeredPlacementName: placementData?.name,
          paywallInfo: paywallInfo,
          attempt: attempt
        )
      case .missingProducts(let identifiers):
        return .paywallProductsLoadMissingProducts(
          triggeredPlacementName: placementData?.name,
          paywallInfo: paywallInfo,
          identifiers: identifiers
        )
      }
    }
    let paywallInfo: PaywallInfo
    let placementData: PlacementData?

    func getSuperwallParameters() async -> [String: Any] {
      let fromPlacement = placementData != nil
      var params: [String: Any] = [
        "is_triggered_from_event": fromPlacement
      ]
      if case .fail(let error) = state {
        params["error_message"] = error.safeLocalizedDescription
      }
      if case .missingProducts(let identifiers) = state {
        params["missing_products"] = Array(identifiers).joined(separator: ",")
      }
      params += await paywallInfo.placementParams()
      return params
    }
  }

  enum ConfigCacheStatus: String {
    case cached = "CACHED"
    case notCached = "NOT_CACHED"
  }

  struct ConfigRefresh: TrackableSuperwallEvent {
    let superwallEvent: SuperwallEvent = .configRefresh
    let buildId: String
    let retryCount: Int
    let cacheStatus: ConfigCacheStatus
    let fetchDuration: TimeInterval
    var audienceFilterParams: [String: Any] = [:]

    func getSuperwallParameters() async -> [String: Any] {
      return [
        "config_build_id": buildId,
        "retry_count": retryCount,
        "cache_status": cacheStatus.rawValue,
        "fetch_duration": fetchDuration
      ]
    }
  }

  struct ConfigFail: TrackableSuperwallEvent {
    let superwallEvent: SuperwallEvent = .configFail
    let message: String
    var audienceFilterParams: [String: Any] = [:]

    func getSuperwallParameters() async -> [String: Any] {
      return [
        "error_message": message
      ]
    }
  }

  struct AdServicesTokenRetrieval: TrackableSuperwallEvent {
    enum State {
      case start
      case fail(Error)
      case complete(String)
    }
    let state: State

    var superwallEvent: SuperwallEvent {
      switch state {
      case .start:
        return .adServicesTokenRequestStart
      case .fail(let error):
        return .adServicesTokenRequestFail(error: error)
      case .complete(let token):
        return .adServicesTokenRequestComplete(token: token)
      }
    }
    let audienceFilterParams: [String: Any] = [:]

    func getSuperwallParameters() async -> [String: Any] {
      switch state {
      case .start:
        return [:]
      case .fail(let error):
        return ["error_message": error.localizedDescription]
      case .complete(let token):
        return [
          "token": token
        ]
      }
    }
  }

  struct ShimmerLoad: TrackableSuperwallEvent {
    enum State {
      case start
      case complete
    }
    let state: State
    let paywallId: String
    var loadDuration: Double?
    var visibleDuration: Double?
    var superwallEvent: SuperwallEvent {
      switch state {
      case .start:
        return .shimmerViewStart
      case .complete:
        return .shimmerViewComplete
      }
    }
    let audienceFilterParams: [String: Any] = [:]
    func getSuperwallParameters() async -> [String: Any] {
      var params: [String: Any] = [
        "paywall_id": paywallId
      ]

      if state == .complete {
        params += [
          "visible_duration": visibleDuration ?? 0.0
        ]
      }
      return params
    }
  }

  struct Redemption: TrackableSuperwallEvent {
    enum State {
      case start
      case complete
      case fail
    }
    let state: State
    let type: WebEntitlementRedeemer.RedeemType

    var superwallEvent: SuperwallEvent {
      switch state {
      case .start:
        return .redemptionStart
      case .complete:
        return .redemptionComplete
      case .fail:
        return .redemptionFail
      }
    }
    let audienceFilterParams: [String: Any] = [:]
    func getSuperwallParameters() async -> [String: Any] {
      var output: [String: Any] = [
        "type": type.description
      ]
      if let code = type.code {
        output["code"] = code
      }
      return output
    }
  }

  struct EnrichmentLoad: TrackableSuperwallEvent {
    enum State {
      case start
      case complete(Enrichment)
      case fail
    }
    let state: State

    var superwallEvent: SuperwallEvent {
      switch state {
      case .start:
        return .enrichmentStart
      case .complete(let enrichment):
        return .enrichmentComplete(
          userEnrichment: enrichment.user.dictionaryObject,
          deviceEnrichment: enrichment.device.dictionaryObject
        )
      case .fail:
        return .enrichmentFail
      }
    }
    let audienceFilterParams: [String: Any] = [:]

    func getSuperwallParameters() async -> [String: Any] {
      var output: [String: Any] = [:]
      switch state {
      case .complete(let enrichment):
        for (key, value) in enrichment.user {
          output["user_\(key)"] = value
        }
        for (key, value) in enrichment.device {
          output["device_\(key)"] = value
        }
        return output
      default:
        return [:]
      }
    }
  }

  struct NetworkDecodingFail: TrackableSuperwallEvent {
    let superwallEvent: SuperwallEvent = .networkDecodingFail
    let requestURLString: String
    let responseString: String
    var audienceFilterParams: [String: Any] = [:]

    func getSuperwallParameters() async -> [String: Any] {
      return [
        "request_url": requestURLString,
        "response": responseString
      ]
    }
  }

  struct ReviewRequested: TrackableSuperwallEvent {
    let count: Int
    let type: ReviewType
    var superwallEvent: SuperwallEvent {
      return .reviewRequested(count: count)
    }
    var audienceFilterParams: [String: Any] = [:]

    func getSuperwallParameters() async -> [String: Any] {
      return [
        "count": count,
        "type": type.rawValue
      ]
    }
  }

  enum PaywallPreloadState: String {
    case start
    case complete
  }

  struct PaywallPreload: TrackableSuperwallEvent {
    let state: PaywallPreloadState
    let paywallCount: Int
    var superwallEvent: SuperwallEvent {
      switch state {
      case .start:
        return .paywallPreloadStart(paywallCount: paywallCount)
      case .complete:
        return .paywallPreloadComplete(paywallCount: paywallCount)
      }
    }
    var audienceFilterParams: [String: Any] = [:]

    func getSuperwallParameters() async -> [String: Any] {
      return [
        "state": state.rawValue,
        "paywall_count": paywallCount
      ]
    }
  }
}
