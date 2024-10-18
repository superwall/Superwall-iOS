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
  /// The ``SuperwallEvent`` to be tracked by this event.
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

protocol TrackablePrivateEvent: Trackable {}

enum PrivateSuperwallEvent {
  struct CELExpressionResult: TrackablePrivateEvent {
    let celExpression: String
    let celExpressionDidMatch: Bool
    let liquidExpression: String
    let liquidExpressionDidMatch: Bool

    let rawName = "cel_expression_result"
    var audienceFilterParams: [String: Any] = [:]
    var canImplicitlyTriggerPaywall = false
    func getSuperwallParameters() async -> [String: Any] {
      return [
        "cel_expression": celExpression,
        "cel_expression_did_match": celExpressionDidMatch,
        "liquid_expression": liquidExpression,
        "liquid_expression_did_match": liquidExpressionDidMatch
      ]
    }
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

      return await paywallInfo.eventParams(otherParams: params)
    }
  }

  struct AppLaunch: TrackableSuperwallEvent {
    let superwallEvent: SuperwallEvent = .appLaunch
    var audienceFilterParams: [String: Any] = [:]
    func getSuperwallParameters() async -> [String: Any] { [:] }
  }

  struct Attributes: TrackableSuperwallEvent {
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

    func getSuperwallParameters() async -> [String: Any] {
      return [
        "url": url.absoluteString,
        "path": url.path,
        "pathExtension": url.pathExtension,
        "lastPathComponent": url.lastPathComponent,
        "host": url.host ?? "",
        "query": url.query ?? "",
        "fragment": url.fragment ?? ""
      ]
    }

    var audienceFilterParams: [String: Any] {
      guard let urlComponents = URLComponents(
        url: url,
        resolvingAgainstBaseURL: false
      ) else {
        return [:]
      }
      guard let queryItems = urlComponents.queryItems else {
        return [:]
      }

      var queryStrings: [String: Any] = [:]
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
          queryStrings[name] = true
        } else if lowerCaseValue == "false" {
          queryStrings[name] = false
        } else if let int = Int(value) {
          queryStrings[name] = int
        } else if let double = Double(value) {
          queryStrings[name] = double
        } else {
          queryStrings[name] = value
        }
      }
      return queryStrings
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
        return .paywallResponseLoadStart(triggeredEventName: eventData?.name)
      case .notFound:
        return .paywallResponseLoadNotFound(triggeredEventName: eventData?.name)
      case .fail:
        return .paywallResponseLoadFail(triggeredEventName: eventData?.name)
      case .complete(let paywallInfo):
        return .paywallResponseLoadComplete(
          triggeredEventName: eventData?.name,
          paywallInfo: paywallInfo
        )
      }
    }
    let eventData: EventData?
    var audienceFilterParams: [String: Any] {
      switch state {
      case .complete(paywallInfo: let paywallInfo):
        return paywallInfo.audienceFilterParams()
      default:
        return [:]
      }
    }

    func getSuperwallParameters() async -> [String: Any] {
      let fromEvent = eventData != nil
      let params: [String: Any] = [
        "is_triggered_from_event": fromEvent
      ]

      switch state {
      case .start,
        .notFound,
        .fail:
        return params
      case .complete(let paywallInfo):
        return await paywallInfo.eventParams(otherParams: params)
      }
    }
  }

  struct SubscriptionStatusDidChange: TrackableSuperwallEvent {
    let superwallEvent: SuperwallEvent = .subscriptionStatusDidChange
    let subscriptionStatus: SubscriptionStatus
    var audienceFilterParams: [String: Any] = [:]
    func getSuperwallParameters() async -> [String: Any] {
      return [
        "subscription_status": subscriptionStatus.description
      ]
    }
  }

  struct TriggerFire: TrackableSuperwallEvent {
    let triggerResult: InternalTriggerResult
    var superwallEvent: SuperwallEvent {
      return .triggerFire(
        eventName: triggerName,
        result: triggerResult.toPublicType()
      )
    }
    let triggerName: String
    var audienceFilterParams: [String: Any] = [:]

    func getSuperwallParameters() async -> [String: Any] {
      var params: [String: Any] = [
        "trigger_name": triggerName
      ]

      // TODO: Remove in v4:
      params["trigger_session_id"] = ""

      switch triggerResult {
      case .noRuleMatch(let unmatchedRules):
        params += [
          "result": "no_rule_match"
        ]
        for unmatchedRule in unmatchedRules {
          params["unmatched_rule_\(unmatchedRule.experimentId)"] = unmatchedRule.source.rawValue
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
      case .eventNotFound:
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
    let eventData: EventData?
    let type: PresentationRequestType
    let status: PaywallPresentationRequestStatus
    let statusReason: PaywallPresentationRequestStatusReason?
    let factory: RuleAttributesFactory & FeatureFlagsFactory & ComputedPropertyRequestsFactory

    var superwallEvent: SuperwallEvent {
      return .paywallPresentationRequest(
        status: status,
        reason: statusReason
      )
    }
    var audienceFilterParams: [String: Any] = [:]
    func getSuperwallParameters() async -> [String: Any] {
      var params = [
        "source_event_name": eventData?.name ?? "",
        "pipeline_type": type.description,
        "status": status.rawValue,
        "status_reason": statusReason?.description ?? ""
      ]

      if let featureFlags = factory.makeFeatureFlags(),
        featureFlags.enableExpressionParameters {
        let computedPropertyRequests = factory.makeComputedPropertyRequests()
        let rules = await factory.makeRuleAttributes(
          forEvent: eventData,
          withComputedProperties: computedPropertyRequests
        )

        if let rulesDictionary = rules.dictionaryObject,
          let jsonData = try? JSONSerialization.data(withJSONObject: rulesDictionary),
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
    func getSuperwallParameters() async -> [String: Any] {
      return await paywallInfo.eventParams()
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

      let eventParams = await paywallInfo.eventParams()
      params += eventParams
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
      return await paywallInfo.eventParams()
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
      var eventParams = await paywallInfo.eventParams()
      eventParams += params
      eventParams += [
        "name": name
      ]
      return eventParams
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
      var eventParams = await paywallInfo.eventParams()
      if case .fail(let message) = state {
        eventParams["error_message"] = message
      }
      return eventParams
    }
  }

  struct Transaction: TrackableSuperwallEvent {
    enum State {
      case start(StoreProduct)
      case fail(TransactionError)
      case abandon(StoreProduct)
      case complete(StoreProduct, StoreTransaction?)
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
          product: product,
          paywallInfo: paywallInfo
        )
      case let .complete(product, model):
        return .transactionComplete(
          transaction: model,
          product: product,
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
    let paywallInfo: PaywallInfo
    let product: StoreProduct?
    let model: StoreTransaction?

    var audienceFilterParams: [String: Any] {
      switch state {
      case .abandon(let product):
        var params = paywallInfo.audienceFilterParams()
        params["abandoned_product_id"] = product.productIdentifier
        return params
      default:
        return paywallInfo.audienceFilterParams()
      }
    }

    func getSuperwallParameters() async -> [String: Any] {
      var eventParams: [String: Any] = [
        "store": "APP_STORE"
      ]

      switch state {
      case .restore:
        eventParams += await paywallInfo.eventParams(forProduct: product)
        if let transactionDict = model?.dictionary(withSnakeCase: true) {
          eventParams += transactionDict
        }
        eventParams["restore_via_purchase_attempt"] = model != nil
        return eventParams
      case .start,
        .abandon,
        .complete,
        .timeout:
        eventParams += await paywallInfo.eventParams(forProduct: product)
        if let transactionDict = model?.dictionary(withSnakeCase: true) {
          eventParams += transactionDict
        }
        return eventParams
      case .fail(let error):
        switch error {
        case .failure(let message, _),
          .pending(let message):
          return await paywallInfo.eventParams(
            forProduct: product,
            otherParams: ["message": message]
          )
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
    var audienceFilterParams: [String: Any] {
      return paywallInfo.audienceFilterParams()
    }

    func getSuperwallParameters() async -> [String: Any] {
      return await paywallInfo.eventParams(forProduct: product)
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
    var audienceFilterParams: [String: Any] {
      return paywallInfo.audienceFilterParams()
    }

    func getSuperwallParameters() async -> [String: Any] {
      return await paywallInfo.eventParams(forProduct: product)
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
    var audienceFilterParams: [String: Any] {
      return paywallInfo.audienceFilterParams()
    }

    func getSuperwallParameters() async -> [String: Any] {
      return await paywallInfo.eventParams(forProduct: product)
    }
  }

  struct PaywallWebviewLoad: TrackableSuperwallEvent {
    enum State {
      case start
      case fail(Error, [URL])
      case timeout
      case complete
      case fallback
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
      }
    }
    let paywallInfo: PaywallInfo

    func getSuperwallParameters() async -> [String: Any] {
      var eventParams = await paywallInfo.eventParams()
      if case .fail(let error, let urls) = state {
        eventParams["error_message"] = error.safeLocalizedDescription
        for (index, url) in urls.enumerated() {
          eventParams["url_\(index)"] = url.absoluteString
        }
      }
      return eventParams
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
    }
    let state: State
    var audienceFilterParams: [String: Any] {
      return paywallInfo.audienceFilterParams()
    }

    var superwallEvent: SuperwallEvent {
      switch state {
      case .start:
        return .paywallProductsLoadStart(triggeredEventName: eventData?.name, paywallInfo: paywallInfo)
      case .fail:
        return .paywallProductsLoadFail(triggeredEventName: eventData?.name, paywallInfo: paywallInfo)
      case .complete:
        return .paywallProductsLoadComplete(triggeredEventName: eventData?.name)
      case .retry(let attempt):
        return .paywallProductsLoadRetry(
          triggeredEventName: eventData?.name,
          paywallInfo: paywallInfo,
          attempt: attempt
        )
      }
    }
    let paywallInfo: PaywallInfo
    let eventData: EventData?

    func getSuperwallParameters() async -> [String: Any] {
      let fromEvent = eventData != nil
      var params: [String: Any] = [
        "is_triggered_from_event": fromEvent
      ]
      if case .fail(let error) = state {
        params["error_message"] = error.safeLocalizedDescription
      }
      params += await paywallInfo.eventParams()
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
}
