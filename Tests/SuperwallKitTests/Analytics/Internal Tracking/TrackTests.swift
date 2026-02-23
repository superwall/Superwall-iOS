//
//  File.swift
//
//
//  Created by Yusuf Tör on 10/03/2023.
//
// swiftlint:disable all

import Testing
import Foundation
@testable import SuperwallKit

@Suite(.serialized)
struct TrackingTests {
  @Test func userInitiatedPlacement() async {
    let eventName = "MyEvent"
    let result = await Superwall.shared.track(
      UserInitiatedPlacement.Track(
        rawName: eventName,
        canImplicitlyTriggerPaywall: false,
        isFeatureGatable: false
      ))
    #expect(result.parameters.audienceFilterParams["$app_session_id"] != nil)
    #expect(!(result.parameters.audienceFilterParams["$is_standard_event"] as! Bool))
    #expect(!(result.parameters.audienceFilterParams["$is_feature_gatable"] as! Bool))
    #expect(result.parameters.audienceFilterParams["$event_name"] as! String == eventName)
  }

  @Test func appOpen() async {
    let result = await Superwall.shared.track(InternalSuperwallEvent.AppOpen())
    #expect(result.parameters.audienceFilterParams["$app_session_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$is_standard_event"] as! Bool)
    #expect(result.parameters.audienceFilterParams["$event_name"] as! String == "app_open")
  }

  @Test func appInstall() async {
    let appInstalledAtString = "now"
    let result = await Superwall.shared.track(
      InternalSuperwallEvent.AppInstall(
        appInstalledAtString: appInstalledAtString, hasExternalPurchaseController: true))
    #expect(result.parameters.audienceFilterParams["$app_session_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$is_standard_event"] as! Bool)
    #expect(result.parameters.audienceFilterParams["$using_purchase_controller"] as! Bool)
    #expect(result.parameters.audienceFilterParams["$event_name"] as! String == "app_install")
    #expect(
      result.parameters.audienceFilterParams["$application_installed_at"] as! String == appInstalledAtString)
  }

  @Test func appLaunch() async {
    let result = await Superwall.shared.track(InternalSuperwallEvent.AppLaunch())
    #expect(result.parameters.audienceFilterParams["$app_session_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$is_standard_event"] as! Bool)
    #expect(result.parameters.audienceFilterParams["$event_name"] as! String == "app_launch")
  }

  @Test func attributes() async {
    let appInstalledAtString = "now"
    let result = await Superwall.shared.track(
      InternalSuperwallEvent.UserAttributes(appInstalledAtString: appInstalledAtString))
    #expect(result.parameters.audienceFilterParams["$app_session_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$is_standard_event"] as! Bool)
    #expect(
      result.parameters.audienceFilterParams["$event_name"] as! String == "user_attributes")
    #expect(
      result.parameters.audienceFilterParams["$application_installed_at"] as! String == appInstalledAtString)
  }

  @Test func deepLink() async {
    let url = URL(string: "http://superwall.com/test?query=value#fragment")!
    let result = await Superwall.shared.track(InternalSuperwallEvent.DeepLink(url: url))
    // "$app_session_id": "B993FB6C-556D-47E0-ADFE-E2E43365D732", "$is_standard_event": false, "$event_name": ""
    print(result)
    #expect(result.parameters.audienceFilterParams["$app_session_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$is_standard_event"] as! Bool)
    #expect(
      result.parameters.audienceFilterParams["$event_name"] as! String == "deepLink_open")
    #expect(result.parameters.audienceFilterParams["$url"] as! String == url.absoluteString)
    #expect(result.parameters.audienceFilterParams["$path"] as! String == url.path)
    #expect(
      result.parameters.audienceFilterParams["$pathExtension"] as! String == url.pathExtension)
    #expect(
      result.parameters.audienceFilterParams["$lastPathComponent"] as! String == url.lastPathComponent
    )
    #expect(result.parameters.audienceFilterParams["$host"] as! String == url.host!)
    #expect(result.parameters.audienceFilterParams["$query"] as! String == url.query!)
    #expect(result.parameters.audienceFilterParams["$fragment"] as! String == url.fragment!)
  }

  @Test func firstSeen() async {
    let result = await Superwall.shared.track(InternalSuperwallEvent.FirstSeen())
    #expect(result.parameters.audienceFilterParams["$app_session_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$is_standard_event"] as! Bool)
    #expect(result.parameters.audienceFilterParams["$event_name"] as! String == "first_seen")
  }

  @Test func appClose() async {
    let result = await Superwall.shared.track(InternalSuperwallEvent.AppClose())
    #expect(result.parameters.audienceFilterParams["$app_session_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$is_standard_event"] as! Bool)
    #expect(result.parameters.audienceFilterParams["$event_name"] as! String == "app_close")
  }

  @Test func sessionStart() async {
    let result = await Superwall.shared.track(InternalSuperwallEvent.SessionStart())
    #expect(result.parameters.audienceFilterParams["$app_session_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$is_standard_event"] as! Bool)
    #expect(
      result.parameters.audienceFilterParams["$event_name"] as! String == "session_start")
  }

  @Test func surveyResponse() async {
    // Given
    let survey = Survey.stub()
    let paywallInfo = PaywallInfo.stub()
    let event = InternalSuperwallEvent.SurveyResponse(
      survey: survey,
      selectedOption: survey.options.first!,
      customResponse: nil,
      paywallInfo: paywallInfo
    )
    // When
    let result = await Superwall.shared.track(event)

    print(result.parameters.audienceFilterParams)

    #expect(result.parameters.audienceFilterParams["$is_standard_event"] as! Bool)
    #expect(
      result.parameters.audienceFilterParams["$event_name"] as! String == "survey_response")
    #expect(result.parameters.audienceFilterParams["$survey_id"] as! String == survey.id)
    #expect(
      result.parameters.audienceFilterParams["$survey_selected_option_id"] as! String == survey.options.first!.id)
    #expect(
      result.parameters.audienceFilterParams["$survey_assignment_key"] as! String == survey.assignmentKey)
    #expect(result.parameters.audienceFilterParams["$survey_custom_response"] == nil)
    #expect(
      result.parameters.audienceFilterParams["survey_selected_option_title"] as! String == survey.assignmentKey)
    #expect(result.parameters.audienceFilterParams["$app_session_id"] != nil)
    #expect(
      result.parameters.audienceFilterParams["$paywall_id"] as! String == paywallInfo.databaseId)
    #expect(
      result.parameters.audienceFilterParams["$paywalljs_version"] as? String ==
      paywallInfo.paywalljsVersion)
    #expect(
      result.parameters.audienceFilterParams["$paywall_identifier"] as! String ==
      paywallInfo.identifier)
    #expect(
      result.parameters.audienceFilterParams["$paywall_name"] as! String == paywallInfo.name)
    #expect(
      result.parameters.audienceFilterParams["$paywall_url"] as! String == paywallInfo.url.absoluteString)
    #expect(
      result.parameters.audienceFilterParams["$presented_by_event_name"] as? String == paywallInfo.presentedByPlacementWithName)
    #expect(
      result.parameters.audienceFilterParams["$presented_by_event_id"] as? String == paywallInfo.presentedByPlacementWithId)
    #expect(
      result.parameters.audienceFilterParams["$presented_by_event_timestamp"] as? String == paywallInfo.presentedByPlacementAt)
    #expect(
      result.parameters.audienceFilterParams["$presented_by"] as! String == paywallInfo.presentedBy)
    #expect(
      result.parameters.audienceFilterParams["$paywall_product_ids"] as? String == paywallInfo.productIds.joined(separator: ","))
    #expect(
      result.parameters.audienceFilterParams["$paywall_response_load_start_time"] as! String == paywallInfo.responseLoadStartTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_response_load_complete_time"] as! String == paywallInfo.responseLoadCompleteTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_response_load_duration"] as? TimeInterval == paywallInfo.responseLoadDuration)
    #expect(
      result.parameters.audienceFilterParams["$paywall_webview_load_start_time"] as! String == paywallInfo.webViewLoadStartTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_webview_load_complete_time"] as! String == paywallInfo.webViewLoadCompleteTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_webview_load_duration"] as? TimeInterval == paywallInfo.webViewLoadDuration)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_start_time"] as! String == paywallInfo.productsLoadStartTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_complete_time"] as! String == paywallInfo.productsLoadCompleteTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_fail_time"] as! String == paywallInfo.productsLoadFailTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_duration"] as? TimeInterval == paywallInfo.productsLoadDuration)
    #expect(
      result.parameters.audienceFilterParams["$is_free_trial_available"] as! Bool == paywallInfo.isFreeTrialAvailable)

    // Custom parameters
    #expect(
      result.parameters.audienceFilterParams["event_name"] as! String == "survey_response")
    #expect(
      result.parameters.audienceFilterParams["survey_selected_option_title"] as! String == survey.assignmentKey)
    #expect(
      result.parameters.audienceFilterParams["paywall_id"] as! String == paywallInfo.databaseId)
    #expect(
      result.parameters.audienceFilterParams["paywall_name"] as! String == paywallInfo.name)
    #expect(
      result.parameters.audienceFilterParams["is_free_trial_available"] as! Bool == paywallInfo.isFreeTrialAvailable)
    #expect(
      result.parameters.audienceFilterParams["feature_gating"] as! String == FeatureGatingBehavior.nonGated.description)
    #expect(
      result.parameters.audienceFilterParams["presented_by"] as! String == paywallInfo.presentedBy)
    #expect(
      result.parameters.audienceFilterParams["paywall_product_ids"] as? String == paywallInfo.productIds.joined(separator: ","))
    #expect(result.parameters.audienceFilterParams["primary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["secondary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["tertiary_product_id"] != nil)
    #expect(
      result.parameters.audienceFilterParams["presented_by_event_name"] as? String == paywallInfo.presentedByPlacementWithName)

    #expect(result.parameters.delegateParams["is_superwall"] as! Bool)
    #expect(
      result.parameters.delegateParams["survey_selected_option_title"] as! String == survey.assignmentKey)
    #expect(result.parameters.delegateParams["survey_id"] as! String == survey.id)
    #expect(
      result.parameters.delegateParams["survey_selected_option_id"] as! String == survey.options.first!.id)
    #expect(
      result.parameters.delegateParams["survey_assignment_key"] as! String == survey.assignmentKey)
    #expect(result.parameters.delegateParams["survey_custom_response"] == nil)
    #expect(
      result.parameters.delegateParams["paywall_id"] as! String == paywallInfo.databaseId)
    #expect(
      result.parameters.delegateParams["paywall_identifier"] as! String == paywallInfo.identifier)
    #expect(result.parameters.delegateParams["paywall_name"] as! String == paywallInfo.name)
    #expect(
      result.parameters.delegateParams["paywall_url"] as! String == paywallInfo.url.absoluteString)
    #expect(
      result.parameters.delegateParams["is_free_trial_available"] as! Bool == paywallInfo.isFreeTrialAvailable)
    #expect(
      result.parameters.audienceFilterParams["feature_gating"] as! String == FeatureGatingBehavior.nonGated.description)
    #expect(
      result.parameters.delegateParams["presented_by"] as! String == paywallInfo.presentedBy)
    #expect(
      result.parameters.delegateParams["paywall_product_ids"] as? String == paywallInfo.productIds.joined(separator: ","))
    #expect(result.parameters.delegateParams["primary_product_id"] != nil)
    #expect(result.parameters.delegateParams["secondary_product_id"] != nil)
    #expect(result.parameters.delegateParams["tertiary_product_id"] != nil)
  }

  @Test func paywallLoad_start() async {
    let eventName = "name"
    let params = ["hello": true]
    let eventData = PlacementData(
      name: eventName,
      parameters: JSON(params),
      createdAt: Date()
    )
    let result = await Superwall.shared.track(
      InternalSuperwallEvent.PaywallLoad(state: .start, placementData: eventData))
    #expect(result.parameters.audienceFilterParams["$app_session_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$is_standard_event"] as! Bool)
    #expect(
      result.parameters.audienceFilterParams["$event_name"] as! String == "paywallResponseLoad_start")
    #expect(result.parameters.audienceFilterParams["$is_triggered_from_event"] as! Bool)
  }

  @Test func paywallLoad_fail() async {
    let eventName = "name"
    let params = ["hello": true]
    let eventData = PlacementData(
      name: eventName,
      parameters: JSON(params),
      createdAt: Date()
    )
    let result = await Superwall.shared.track(
      InternalSuperwallEvent.PaywallLoad(state: .fail, placementData: eventData))
    #expect(result.parameters.audienceFilterParams["$app_session_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$is_standard_event"] as! Bool)
    #expect(
      result.parameters.audienceFilterParams["$event_name"] as! String == "paywallResponseLoad_fail")
    #expect(result.parameters.audienceFilterParams["$is_triggered_from_event"] as! Bool)
  }

  @Test func paywallLoad_notFound() async {
    let eventName = "name"
    let params = ["hello": true]
    let eventData = PlacementData(
      name: eventName,
      parameters: JSON(params),
      createdAt: Date()
    )
    let result = await Superwall.shared.track(
      InternalSuperwallEvent.PaywallLoad(state: .notFound, placementData: eventData))
    #expect(result.parameters.audienceFilterParams["$app_session_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$is_standard_event"] as! Bool)
    #expect(
      result.parameters.audienceFilterParams["$event_name"] as! String == "paywallResponseLoad_notFound")
    #expect(result.parameters.audienceFilterParams["$is_triggered_from_event"] as! Bool)
  }

  @Test func paywallLoad_complete() async {
    let eventName = "name"
    let params = ["hello": true]
    let eventData = PlacementData(
      name: eventName,
      parameters: JSON(params),
      createdAt: Date()
    )
    let paywallInfo = PaywallInfo.stub()
    let result = await Superwall.shared.track(
      InternalSuperwallEvent.PaywallLoad(
        state: .complete(paywallInfo: paywallInfo), placementData: eventData))
    #expect(result.parameters.audienceFilterParams["$app_session_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$is_standard_event"] as! Bool)
    #expect(
      result.parameters.audienceFilterParams["$event_name"] as! String == "paywallResponseLoad_complete")
    #expect(result.parameters.audienceFilterParams["$is_triggered_from_event"] as! Bool)
    #expect(
      result.parameters.audienceFilterParams["$paywall_id"] as! String == paywallInfo.databaseId)
    #expect(
      result.parameters.audienceFilterParams["$paywalljs_version"] as? String ==
      paywallInfo.paywalljsVersion)
    #expect(
      result.parameters.audienceFilterParams["$paywall_identifier"] as! String ==
      paywallInfo.identifier)
    #expect(
      result.parameters.audienceFilterParams["$paywall_name"] as! String == paywallInfo.name)
    #expect(
      result.parameters.audienceFilterParams["$paywall_url"] as! String == paywallInfo.url.absoluteString)
    #expect(
      result.parameters.audienceFilterParams["$presented_by_event_name"] as? String == paywallInfo.presentedByPlacementWithName)
    #expect(
      result.parameters.audienceFilterParams["$presented_by_event_id"] as? String == paywallInfo.presentedByPlacementWithId)
    #expect(
      result.parameters.audienceFilterParams["$presented_by_event_timestamp"] as? String == paywallInfo.presentedByPlacementAt)
    #expect(
      result.parameters.audienceFilterParams["$presented_by"] as! String == paywallInfo.presentedBy)
    #expect(
      result.parameters.audienceFilterParams["$paywall_product_ids"] as? String == paywallInfo.productIds.joined(separator: ","))
    #expect(
      result.parameters.audienceFilterParams["$paywall_response_load_start_time"] as! String == paywallInfo.responseLoadStartTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_response_load_complete_time"] as! String == paywallInfo.responseLoadCompleteTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_response_load_duration"] as? TimeInterval == paywallInfo.responseLoadDuration)
    #expect(
      result.parameters.audienceFilterParams["$paywall_webview_load_start_time"] as! String == paywallInfo.webViewLoadStartTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_webview_load_complete_time"] as! String == paywallInfo.webViewLoadCompleteTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_webview_load_duration"] as? TimeInterval == paywallInfo.webViewLoadDuration)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_start_time"] as! String == paywallInfo.productsLoadStartTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_complete_time"] as! String == paywallInfo.productsLoadCompleteTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_fail_time"] as! String == paywallInfo.productsLoadFailTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_duration"] as? TimeInterval == paywallInfo.productsLoadDuration)
    #expect(
      result.parameters.audienceFilterParams["$is_free_trial_available"] as! Bool == paywallInfo.isFreeTrialAvailable)

    // Custom parameters
    #expect(
      result.parameters.audienceFilterParams["event_name"] as! String == "paywallResponseLoad_complete")
    #expect(
      result.parameters.audienceFilterParams["paywall_id"] as! String == paywallInfo.databaseId)
    #expect(
      result.parameters.audienceFilterParams["paywall_name"] as! String == paywallInfo.name)
    #expect(
      result.parameters.audienceFilterParams["is_free_trial_available"] as! Bool == paywallInfo.isFreeTrialAvailable)
    #expect(
      result.parameters.audienceFilterParams["feature_gating"] as! String == FeatureGatingBehavior.nonGated.description)
    #expect(
      result.parameters.audienceFilterParams["presented_by"] as! String == paywallInfo.presentedBy)
    #expect(
      result.parameters.audienceFilterParams["paywall_product_ids"] as? String == paywallInfo.productIds.joined(separator: ","))
    #expect(result.parameters.audienceFilterParams["primary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["secondary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["tertiary_product_id"] != nil)
    #expect(
      result.parameters.audienceFilterParams["presented_by_event_name"] as? String == paywallInfo.presentedByPlacementWithName)
  }

  @Test func subscriptionStatusDidChange_hasOneEntitlement() async {
    let entitlements: Set<Entitlement> = [.stub()]
    let result = await Superwall.shared.track(
      InternalSuperwallEvent.SubscriptionStatusDidChange(status: .active([.stub()])))
    #expect(result.parameters.audienceFilterParams["$app_session_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$is_standard_event"] as! Bool)
    #expect(
      result.parameters.audienceFilterParams["$event_name"] as! String == "subscriptionStatus_didChange")
    #expect(result.parameters.audienceFilterParams["$status"] as! String == "ACTIVE")
    #expect(
      result.parameters.audienceFilterParams["$active_entitlement_ids"] as! String == entitlements.map { $0.id }.joined(separator: ","))
  }

  @Test func subscriptionStatusDidChange_hasTwoEntitlements() async {
    let entitlements: Set<Entitlement> = [.stub(), Entitlement(id: "test2", type: .serviceLevel)]
    let result = await Superwall.shared.track(
      InternalSuperwallEvent.SubscriptionStatusDidChange(status: .active(entitlements)))
    #expect(result.parameters.audienceFilterParams["$app_session_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$is_standard_event"] as! Bool)
    #expect(
      result.parameters.audienceFilterParams["$event_name"] as! String == "subscriptionStatus_didChange")
    #expect(result.parameters.audienceFilterParams["$status"] as! String == "ACTIVE")
    #expect(
      result.parameters.audienceFilterParams["$active_entitlement_ids"] as! String == entitlements.map { $0.id }.joined(separator: ","))
  }

  @Test func subscriptionStatusDidChange_noEntitlements() async {
    let result = await Superwall.shared.track(
      InternalSuperwallEvent.SubscriptionStatusDidChange(status: .inactive))
    #expect(result.parameters.audienceFilterParams["$app_session_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$is_standard_event"] as! Bool)
    #expect(
      result.parameters.audienceFilterParams["$event_name"] as! String == "subscriptionStatus_didChange")
    #expect(result.parameters.audienceFilterParams["$status"] as! String == "INACTIVE")
    #expect(result.parameters.audienceFilterParams["$active_entitlement_ids"] as? String == nil)
  }

  @Test func triggerFire_noRuleMatch() async {
    let triggerName = "My Trigger"
    let unmatchedRules: [UnmatchedAudience] = [
      .init(source: .expression, experimentId: "1"),
      .init(source: .occurrence, experimentId: "2"),
    ]
    let result = await Superwall.shared.track(
      InternalSuperwallEvent.TriggerFire(
        triggerResult: .noAudienceMatch(unmatchedRules), triggerName: triggerName))
    #expect(result.parameters.audienceFilterParams["$app_session_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$is_standard_event"] as! Bool)
    #expect(result.parameters.audienceFilterParams["$event_name"] as! String == "trigger_fire")
    #expect(result.parameters.audienceFilterParams["$result"] as! String == "no_rule_match")
    #expect(result.parameters.audienceFilterParams["$trigger_name"] as! String == triggerName)
    #expect(
      result.parameters.audienceFilterParams["$unmatched_audience_1"] as! String == "EXPRESSION")
    #expect(
      result.parameters.audienceFilterParams["$unmatched_audience_2"] as! String == "OCCURRENCE")
    // TODO: Missing test for trigger_session_id here. Need to figure out a way to activate it
  }

  @Test func triggerFire_holdout() async {
    let triggerName = "My Trigger"
    let experiment: Experiment = .stub()
    let result = await Superwall.shared.track(
      InternalSuperwallEvent.TriggerFire(
        triggerResult: .holdout(experiment), triggerName: triggerName))
    #expect(result.parameters.audienceFilterParams["$app_session_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$is_standard_event"] as! Bool)
    #expect(result.parameters.audienceFilterParams["$event_name"] as! String == "trigger_fire")
    #expect(result.parameters.audienceFilterParams["$trigger_name"] as! String == triggerName)
    #expect(result.parameters.audienceFilterParams["$result"] as! String == "holdout")
    #expect(result.parameters.audienceFilterParams["$trigger_name"] as! String == triggerName)
    #expect(
      result.parameters.audienceFilterParams["$variant_id"] as! String == experiment.variant.id)
    #expect(
      result.parameters.audienceFilterParams["$experiment_id"] as! String == experiment.id)
  }

  @Test func triggerFire_paywall() async {
    let triggerName = "My Trigger"
    let experiment: Experiment = .stub()
    let result = await Superwall.shared.track(
      InternalSuperwallEvent.TriggerFire(
        triggerResult: .paywall(experiment), triggerName: triggerName))
    #expect(result.parameters.audienceFilterParams["$app_session_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$is_standard_event"] as! Bool)
    #expect(result.parameters.audienceFilterParams["$event_name"] as! String == "trigger_fire")
    #expect(result.parameters.audienceFilterParams["$trigger_name"] as! String == triggerName)
    #expect(result.parameters.audienceFilterParams["$result"] as! String == "present")
    #expect(result.parameters.audienceFilterParams["$trigger_name"] as! String == triggerName)
    #expect(
      result.parameters.audienceFilterParams["$variant_id"] as! String == experiment.variant.id)
    #expect(
      result.parameters.audienceFilterParams["$paywall_identifier"] as! String == experiment.variant.paywallId!)
    #expect(
      result.parameters.audienceFilterParams["$experiment_id"] as! String == experiment.id)
  }

  @Test func triggerFire_eventNotFound() async {
    let triggerName = "My Trigger"
    let result = await Superwall.shared.track(
      InternalSuperwallEvent.TriggerFire(
        triggerResult: .placementNotFound, triggerName: triggerName))
    print(result)
    #expect(result.parameters.audienceFilterParams["$app_session_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$is_standard_event"] as! Bool)
    #expect(result.parameters.audienceFilterParams["$result"] as! String == "eventNotFound")
    #expect(result.parameters.audienceFilterParams["$event_name"] as! String == "trigger_fire")
  }

  @Test func triggerFire_error() async {
    let triggerName = "My Trigger"
    let error = NSError(domain: "com.superwall", code: 400)
    let result = await Superwall.shared.track(
      InternalSuperwallEvent.TriggerFire(triggerResult: .error(error), triggerName: triggerName)
    )
    print(result)
    #expect(result.parameters.audienceFilterParams["$app_session_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$is_standard_event"] as! Bool)
    #expect(result.parameters.audienceFilterParams["$result"] as! String == "error")
    #expect(result.parameters.audienceFilterParams["$event_name"] as! String == "trigger_fire")
  }

  @Test func presentationRequest_eventNotFound() async {
    let dependencyContainer = DependencyContainer()
    let placementData: PlacementData = .stub()
    let event = InternalSuperwallEvent.PresentationRequest(
      placementData: placementData,
      type: .getPaywall(.stub()),
      status: .noPresentation,
      statusReason: .placementNotFound,
      factory: dependencyContainer
    )
    let result = await Superwall.shared.track(event)
    #expect(result.parameters.audienceFilterParams["$app_session_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$is_standard_event"] as! Bool)
    #expect(
      result.parameters.audienceFilterParams["$event_name"] as! String == "paywallPresentationRequest"
    )
    #expect(
      result.parameters.audienceFilterParams["$source_event_name"] as! String == placementData.name)
    #expect(result.parameters.audienceFilterParams["$status"] as! String == "no_presentation")
    #expect(
      result.parameters.audienceFilterParams["$pipeline_type"] as! String == "getPaywallViewController")
    #expect(
      result.parameters.audienceFilterParams["$status_reason"] as! String == "event_not_found")
  }

  @Test func presentationRequest_noRuleMatch() async {
    let dependencyContainer = DependencyContainer()
    let placementData: PlacementData = .stub()
    let event = InternalSuperwallEvent.PresentationRequest(
      placementData: placementData,
      type: .getPaywall(.stub()),
      status: .noPresentation,
      statusReason: .noAudienceMatch,
      factory: dependencyContainer
    )
    let result = await Superwall.shared.track(event)
    #expect(result.parameters.audienceFilterParams["$app_session_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$is_standard_event"] as! Bool)
    #expect(
      result.parameters.audienceFilterParams["$event_name"] as! String == "paywallPresentationRequest"
    )
    #expect(
      result.parameters.audienceFilterParams["$source_event_name"] as! String == placementData.name)
    #expect(result.parameters.audienceFilterParams["$status"] as! String == "no_presentation")
    #expect(
      result.parameters.audienceFilterParams["$pipeline_type"] as! String == "getPaywallViewController")
    #expect(
      result.parameters.audienceFilterParams["$status_reason"] as! String == "no_rule_match")
    #expect(result.parameters.audienceFilterParams["$expression_params"] as? String == nil)
  }

  @Test func presentationRequest_expressionParams() async {
    let dependencyContainer = DependencyContainer()
    dependencyContainer.configManager.configState.send(
      .retrieved(.stub().setting(\.featureFlags.enableExpressionParameters, to: true)))
    let placementData: PlacementData = .stub()
    let event = InternalSuperwallEvent.PresentationRequest(
      placementData: placementData,
      type: .getPaywall(.stub()),
      status: .noPresentation,
      statusReason: .noAudienceMatch,
      factory: dependencyContainer
    )
    let result = await Superwall.shared.track(event)
    #expect(result.parameters.audienceFilterParams["$app_session_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$is_standard_event"] as! Bool)
    #expect(
      result.parameters.audienceFilterParams["$event_name"] as! String == "paywallPresentationRequest"
    )
    #expect(
      result.parameters.audienceFilterParams["$source_event_name"] as! String == placementData.name)
    #expect(result.parameters.audienceFilterParams["$status"] as! String == "no_presentation")
    #expect(
      result.parameters.audienceFilterParams["$pipeline_type"] as! String == "getPaywallViewController")
    #expect(
      result.parameters.audienceFilterParams["$status_reason"] as! String == "no_rule_match")
    #expect(result.parameters.audienceFilterParams["$expression_params"] as? String != nil)
  }

  @Test func presentationRequest_alreadyPresented() async {
    let dependencyContainer = DependencyContainer()
    let placementData: PlacementData = .stub()
    let event = InternalSuperwallEvent.PresentationRequest(
      placementData: placementData,
      type: .getPaywall(.stub()),
      status: .noPresentation,
      statusReason: .paywallAlreadyPresented,
      factory: dependencyContainer
    )
    let result = await Superwall.shared.track(event)
    #expect(result.parameters.audienceFilterParams["$app_session_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$is_standard_event"] as! Bool)
    #expect(
      result.parameters.audienceFilterParams["$event_name"] as! String == "paywallPresentationRequest"
    )
    #expect(
      result.parameters.audienceFilterParams["$source_event_name"] as! String == placementData.name)
    #expect(result.parameters.audienceFilterParams["$status"] as! String == "no_presentation")
    #expect(
      result.parameters.audienceFilterParams["$pipeline_type"] as! String == "getPaywallViewController")
    #expect(
      result.parameters.audienceFilterParams["$status_reason"] as! String == "paywall_already_presented")
  }
  // TODO: Add test for expression params
  @Test func presentationRequest_debuggerLaunched() async {
    let dependencyContainer = DependencyContainer()
    let placementData: PlacementData = .stub()
    let event = InternalSuperwallEvent.PresentationRequest(
      placementData: placementData,
      type: .getPaywall(.stub()),
      status: .noPresentation,
      statusReason: .debuggerPresented,
      factory: dependencyContainer
    )
    let result = await Superwall.shared.track(event)
    #expect(result.parameters.audienceFilterParams["$app_session_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$is_standard_event"] as! Bool)
    #expect(
      result.parameters.audienceFilterParams["$event_name"] as! String == "paywallPresentationRequest"
    )
    #expect(
      result.parameters.audienceFilterParams["$source_event_name"] as! String == placementData.name)
    #expect(result.parameters.audienceFilterParams["$status"] as! String == "no_presentation")
    #expect(
      result.parameters.audienceFilterParams["$pipeline_type"] as! String == "getPaywallViewController")
    #expect(
      result.parameters.audienceFilterParams["$status_reason"] as! String == "debugger_presented")
  }

  @Test func presentationRequest_noPresenter() async {
    let dependencyContainer = DependencyContainer()
    let placementData: PlacementData = .stub()
    let event = InternalSuperwallEvent.PresentationRequest(
      placementData: placementData,
      type: .getPaywall(.stub()),
      status: .noPresentation,
      statusReason: .noPresenter,
      factory: dependencyContainer
    )
    let result = await Superwall.shared.track(event)
    #expect(result.parameters.audienceFilterParams["$app_session_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$is_standard_event"] as! Bool)
    #expect(
      result.parameters.audienceFilterParams["$event_name"] as! String == "paywallPresentationRequest"
    )
    #expect(
      result.parameters.audienceFilterParams["$source_event_name"] as! String == placementData.name)
    #expect(result.parameters.audienceFilterParams["$status"] as! String == "no_presentation")
    #expect(
      result.parameters.audienceFilterParams["$pipeline_type"] as! String == "getPaywallViewController")
    #expect(
      result.parameters.audienceFilterParams["$status_reason"] as! String == "no_presenter")
  }

  @Test func presentationRequest_noPaywallViewController() async {
    let dependencyContainer = DependencyContainer()
    let placementData: PlacementData = .stub()
    let event = InternalSuperwallEvent.PresentationRequest(
      placementData: placementData,
      type: .getPaywall(.stub()),
      status: .noPresentation,
      statusReason: .noPaywallViewController,
      factory: dependencyContainer
    )
    let result = await Superwall.shared.track(event)
    #expect(result.parameters.audienceFilterParams["$app_session_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$is_standard_event"] as! Bool)
    #expect(
      result.parameters.audienceFilterParams["$event_name"] as! String == "paywallPresentationRequest"
    )
    #expect(
      result.parameters.audienceFilterParams["$source_event_name"] as! String == placementData.name)
    #expect(result.parameters.audienceFilterParams["$status"] as! String == "no_presentation")
    #expect(
      result.parameters.audienceFilterParams["$pipeline_type"] as! String == "getPaywallViewController")
    #expect(
      result.parameters.audienceFilterParams["$status_reason"] as! String == "no_paywall_view_controller")
  }

  @Test func presentationRequest_holdout() async {
    let dependencyContainer = DependencyContainer()
    let placementData: PlacementData = .stub()
    let event = InternalSuperwallEvent.PresentationRequest(
      placementData: placementData,
      type: .getPaywall(.stub()),
      status: .noPresentation,
      statusReason: .holdout(.stub()),
      factory: dependencyContainer
    )
    let result = await Superwall.shared.track(event)
    #expect(result.parameters.audienceFilterParams["$app_session_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$is_standard_event"] as! Bool)
    #expect(
      result.parameters.audienceFilterParams["$event_name"] as! String == "paywallPresentationRequest"
    )
    #expect(
      result.parameters.audienceFilterParams["$source_event_name"] as! String == placementData.name)
    #expect(result.parameters.audienceFilterParams["$status"] as! String == "no_presentation")
    #expect(
      result.parameters.audienceFilterParams["$pipeline_type"] as! String == "getPaywallViewController")
    #expect(result.parameters.audienceFilterParams["$status_reason"] as! String == "holdout")
  }

  @Test func paywallOpen() async {
    let paywallInfo: PaywallInfo = .stub()
    let result = await Superwall.shared.track(
      InternalSuperwallEvent.PaywallOpen(paywallInfo: paywallInfo, demandScore: 80, demandTier: "Platinum"))
    #expect(result.parameters.audienceFilterParams["$app_session_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$is_standard_event"] as! Bool)

    #expect(
      result.parameters.audienceFilterParams["$paywall_id"] as! String == paywallInfo.databaseId)
    #expect(
      result.parameters.audienceFilterParams["$paywalljs_version"] as? String ==
      paywallInfo.paywalljsVersion)
    #expect(
      result.parameters.audienceFilterParams["$paywall_identifier"] as! String ==
      paywallInfo.identifier)
    #expect(
      result.parameters.audienceFilterParams["$paywall_name"] as! String == paywallInfo.name)
    #expect(
      result.parameters.audienceFilterParams["$paywall_url"] as! String == paywallInfo.url.absoluteString)
    #expect(
      result.parameters.audienceFilterParams["$presented_by_event_name"] as? String == paywallInfo.presentedByPlacementWithName)
    #expect(
      result.parameters.audienceFilterParams["$presented_by_event_id"] as? String == paywallInfo.presentedByPlacementWithId)
    #expect(
      result.parameters.audienceFilterParams["$presented_by_event_timestamp"] as? String == paywallInfo.presentedByPlacementAt)
    #expect(
      result.parameters.audienceFilterParams["$presented_by"] as! String == paywallInfo.presentedBy)
    #expect(
      result.parameters.audienceFilterParams["$presentation_source_type"] as? String == paywallInfo.presentationSourceType)
    #expect(
      result.parameters.audienceFilterParams["$paywall_product_ids"] as? String == paywallInfo.productIds.joined(separator: ","))
    #expect(
      result.parameters.audienceFilterParams["$paywall_response_load_start_time"] as! String == paywallInfo.responseLoadStartTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_response_load_complete_time"] as! String == paywallInfo.responseLoadCompleteTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_response_load_duration"] as? TimeInterval == paywallInfo.responseLoadDuration)
    #expect(
      result.parameters.audienceFilterParams["$paywall_webview_load_start_time"] as! String == paywallInfo.webViewLoadStartTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_webview_load_complete_time"] as! String == paywallInfo.webViewLoadCompleteTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_webview_load_duration"] as? TimeInterval == paywallInfo.webViewLoadDuration)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_start_time"] as! String == paywallInfo.productsLoadStartTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_complete_time"] as! String == paywallInfo.productsLoadCompleteTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_fail_time"] as! String == paywallInfo.productsLoadFailTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_duration"] as? TimeInterval == paywallInfo.productsLoadDuration)
    #expect(
      result.parameters.audienceFilterParams["$is_free_trial_available"] as! Bool == paywallInfo.isFreeTrialAvailable)
    #expect(result.parameters.audienceFilterParams["$event_name"] as! String == "paywall_open")
    #expect(result.parameters.audienceFilterParams["$attr_demandScore"] as! Int == 80)
    #expect(result.parameters.audienceFilterParams["$attr_demandTier"] as! String == "Platinum")

    // Custom parameters
    #expect(result.parameters.audienceFilterParams["event_name"] as! String == "paywall_open")
    #expect(
      result.parameters.audienceFilterParams["paywall_id"] as! String == paywallInfo.databaseId)
    #expect(
      result.parameters.audienceFilterParams["paywall_name"] as! String == paywallInfo.name)
    #expect(
      result.parameters.audienceFilterParams["is_free_trial_available"] as! Bool == paywallInfo.isFreeTrialAvailable)
    #expect(
      result.parameters.audienceFilterParams["feature_gating"] as! String == FeatureGatingBehavior.nonGated.description)
    #expect(
      result.parameters.audienceFilterParams["presented_by"] as! String == paywallInfo.presentedBy)
    #expect(
      result.parameters.audienceFilterParams["paywall_product_ids"] as? String == paywallInfo.productIds.joined(separator: ","))
    #expect(result.parameters.audienceFilterParams["primary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["secondary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["tertiary_product_id"] != nil)
    #expect(
      result.parameters.audienceFilterParams["presented_by_event_name"] as? String == paywallInfo.presentedByPlacementWithName)
  }

  @Test func paywallClose_survey_show() async {
    let paywall: Paywall = .stub()
      .setting(\.surveys, to: [.stub()])
    let paywallInfo = paywall.getInfo(fromPlacement: .stub())
    let result = await Superwall.shared.track(
      InternalSuperwallEvent.PaywallClose(
        paywallInfo: paywallInfo,
        surveyPresentationResult: .show
      )
    )
    #expect(result.parameters.audienceFilterParams["$app_session_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$is_standard_event"] as! Bool)

    #expect(
      result.parameters.audienceFilterParams["$paywall_id"] as! String == paywallInfo.databaseId)
    #expect(
      result.parameters.audienceFilterParams["$paywalljs_version"] as? String ==
      paywallInfo.paywalljsVersion)
    #expect(
      result.parameters.audienceFilterParams["$paywall_identifier"] as! String ==
      paywallInfo.identifier)
    #expect(
      result.parameters.audienceFilterParams["$paywall_name"] as! String == paywallInfo.name)
    #expect(
      result.parameters.audienceFilterParams["$paywall_url"] as! String == paywallInfo.url.absoluteString)
    #expect(
      result.parameters.audienceFilterParams["$presented_by_event_name"] as? String == paywallInfo.presentedByPlacementWithName)
    #expect(
      result.parameters.audienceFilterParams["$presented_by_event_id"] as? String == paywallInfo.presentedByPlacementWithId)
    #expect(
      result.parameters.audienceFilterParams["$presented_by_event_timestamp"] as? String == paywallInfo.presentedByPlacementAt)
    #expect(
      result.parameters.audienceFilterParams["$presented_by"] as! String == paywallInfo.presentedBy)
    #expect(
      result.parameters.audienceFilterParams["$paywall_product_ids"] as? String == paywallInfo.productIds.joined(separator: ","))
    #expect(
      result.parameters.audienceFilterParams["$paywall_response_load_start_time"] as! String == paywallInfo.responseLoadStartTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_response_load_complete_time"] as! String == paywallInfo.responseLoadCompleteTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_response_load_duration"] as? TimeInterval == paywallInfo.responseLoadDuration)
    #expect(
      result.parameters.audienceFilterParams["$paywall_webview_load_start_time"] as! String == paywallInfo.webViewLoadStartTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_webview_load_complete_time"] as! String == paywallInfo.webViewLoadCompleteTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_webview_load_duration"] as? TimeInterval == paywallInfo.webViewLoadDuration)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_start_time"] as! String == paywallInfo.productsLoadStartTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_complete_time"] as! String == paywallInfo.productsLoadCompleteTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_fail_time"] as! String == paywallInfo.productsLoadFailTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_duration"] as? TimeInterval == paywallInfo.productsLoadDuration)
    #expect(
      result.parameters.audienceFilterParams["$is_free_trial_available"] as! Bool == paywallInfo.isFreeTrialAvailable)
    #expect(
      result.parameters.audienceFilterParams["$event_name"] as! String == "paywall_close")
    #expect(result.parameters.audienceFilterParams["$survey_attached"] as! Bool)
    #expect(
      result.parameters.audienceFilterParams["$survey_presentation"] as! String == "show")

    // Custom parameters
    #expect(result.parameters.audienceFilterParams["event_name"] as! String == "paywall_close")
    #expect(
      result.parameters.audienceFilterParams["paywall_id"] as! String == paywallInfo.databaseId)
    #expect(
      result.parameters.audienceFilterParams["paywall_name"] as! String == paywallInfo.name)
    #expect(
      result.parameters.audienceFilterParams["is_free_trial_available"] as! Bool == paywallInfo.isFreeTrialAvailable)
    #expect(
      result.parameters.audienceFilterParams["feature_gating"] as! String == FeatureGatingBehavior.nonGated.description)
    #expect(
      result.parameters.audienceFilterParams["presented_by"] as! String == paywallInfo.presentedBy)
    #expect(
      result.parameters.audienceFilterParams["paywall_product_ids"] as? String == paywallInfo.productIds.joined(separator: ","))
    #expect(result.parameters.audienceFilterParams["primary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["secondary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["tertiary_product_id"] != nil)
    #expect(
      result.parameters.audienceFilterParams["presented_by_event_name"] as? String == paywallInfo.presentedByPlacementWithName)
  }

  @Test func paywallClose_survey_noShow() async {
    let paywall: Paywall = .stub()
      .setting(\.surveys, to: [.stub()])
    let paywallInfo = paywall.getInfo(fromPlacement: .stub())
    let result = await Superwall.shared.track(
      InternalSuperwallEvent.PaywallClose(
        paywallInfo: paywallInfo,
        surveyPresentationResult: .noShow
      )
    )
    #expect(result.parameters.audienceFilterParams["$app_session_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$is_standard_event"] as! Bool)

    #expect(
      result.parameters.audienceFilterParams["$paywall_id"] as! String == paywallInfo.databaseId)
    #expect(
      result.parameters.audienceFilterParams["$paywalljs_version"] as? String ==
      paywallInfo.paywalljsVersion)
    #expect(
      result.parameters.audienceFilterParams["$paywall_identifier"] as! String ==
      paywallInfo.identifier)
    #expect(
      result.parameters.audienceFilterParams["$paywall_name"] as! String == paywallInfo.name)
    #expect(
      result.parameters.audienceFilterParams["$paywall_url"] as! String == paywallInfo.url.absoluteString)
    #expect(
      result.parameters.audienceFilterParams["$presented_by_event_name"] as? String == paywallInfo.presentedByPlacementWithName)
    #expect(
      result.parameters.audienceFilterParams["$presented_by_event_id"] as? String == paywallInfo.presentedByPlacementWithId)
    #expect(
      result.parameters.audienceFilterParams["$presented_by_event_timestamp"] as? String == paywallInfo.presentedByPlacementAt)
    #expect(
      result.parameters.audienceFilterParams["$presented_by"] as! String == paywallInfo.presentedBy)
    #expect(
      result.parameters.audienceFilterParams["$paywall_product_ids"] as? String == paywallInfo.productIds.joined(separator: ","))
    #expect(
      result.parameters.audienceFilterParams["$paywall_response_load_start_time"] as! String == paywallInfo.responseLoadStartTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_response_load_complete_time"] as! String == paywallInfo.responseLoadCompleteTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_response_load_duration"] as? TimeInterval == paywallInfo.responseLoadDuration)
    #expect(
      result.parameters.audienceFilterParams["$paywall_webview_load_start_time"] as! String == paywallInfo.webViewLoadStartTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_webview_load_complete_time"] as! String == paywallInfo.webViewLoadCompleteTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_webview_load_duration"] as? TimeInterval == paywallInfo.webViewLoadDuration)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_start_time"] as! String == paywallInfo.productsLoadStartTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_complete_time"] as! String == paywallInfo.productsLoadCompleteTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_fail_time"] as! String == paywallInfo.productsLoadFailTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_duration"] as? TimeInterval == paywallInfo.productsLoadDuration)
    #expect(
      result.parameters.audienceFilterParams["$is_free_trial_available"] as! Bool == paywallInfo.isFreeTrialAvailable)
    #expect(
      result.parameters.audienceFilterParams["$event_name"] as! String == "paywall_close")
    #expect(result.parameters.audienceFilterParams["$survey_attached"] as! Bool)
    #expect(result.parameters.audienceFilterParams["$survey_presentation"] == nil)

    // Custom parameters
    #expect(result.parameters.audienceFilterParams["event_name"] as! String == "paywall_close")
    #expect(
      result.parameters.audienceFilterParams["paywall_id"] as! String == paywallInfo.databaseId)
    #expect(
      result.parameters.audienceFilterParams["paywall_name"] as! String == paywallInfo.name)
    #expect(
      result.parameters.audienceFilterParams["is_free_trial_available"] as! Bool == paywallInfo.isFreeTrialAvailable)
    #expect(
      result.parameters.audienceFilterParams["feature_gating"] as! String == FeatureGatingBehavior.nonGated.description)
    #expect(
      result.parameters.audienceFilterParams["presented_by"] as! String == paywallInfo.presentedBy)
    #expect(
      result.parameters.audienceFilterParams["paywall_product_ids"] as? String == paywallInfo.productIds.joined(separator: ","))
    #expect(result.parameters.audienceFilterParams["primary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["secondary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["tertiary_product_id"] != nil)
    #expect(
      result.parameters.audienceFilterParams["presented_by_event_name"] as? String == paywallInfo.presentedByPlacementWithName)
  }

  @Test func paywallClose_survey_holdout() async {
    let paywall: Paywall = .stub()
      .setting(\.surveys, to: [.stub()])
    let paywallInfo = paywall.getInfo(fromPlacement: .stub())
    let result = await Superwall.shared.track(
      InternalSuperwallEvent.PaywallClose(
        paywallInfo: paywallInfo,
        surveyPresentationResult: .holdout
      )
    )
    #expect(result.parameters.audienceFilterParams["$app_session_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$is_standard_event"] as! Bool)

    #expect(
      result.parameters.audienceFilterParams["$paywall_id"] as! String == paywallInfo.databaseId)
    #expect(
      result.parameters.audienceFilterParams["$paywalljs_version"] as? String ==
      paywallInfo.paywalljsVersion)
    #expect(
      result.parameters.audienceFilterParams["$paywall_identifier"] as! String ==
      paywallInfo.identifier)
    #expect(
      result.parameters.audienceFilterParams["$paywall_name"] as! String == paywallInfo.name)
    #expect(
      result.parameters.audienceFilterParams["$paywall_url"] as! String == paywallInfo.url.absoluteString)
    #expect(
      result.parameters.audienceFilterParams["$presented_by_event_name"] as? String == paywallInfo.presentedByPlacementWithName)
    #expect(
      result.parameters.audienceFilterParams["$presented_by_event_id"] as? String == paywallInfo.presentedByPlacementWithId)
    #expect(
      result.parameters.audienceFilterParams["$presented_by_event_timestamp"] as? String == paywallInfo.presentedByPlacementAt)
    #expect(
      result.parameters.audienceFilterParams["$presented_by"] as! String == paywallInfo.presentedBy)
    #expect(
      result.parameters.audienceFilterParams["$paywall_product_ids"] as? String == paywallInfo.productIds.joined(separator: ","))
    #expect(
      result.parameters.audienceFilterParams["$paywall_response_load_start_time"] as! String == paywallInfo.responseLoadStartTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_response_load_complete_time"] as! String == paywallInfo.responseLoadCompleteTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_response_load_duration"] as? TimeInterval == paywallInfo.responseLoadDuration)
    #expect(
      result.parameters.audienceFilterParams["$paywall_webview_load_start_time"] as! String == paywallInfo.webViewLoadStartTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_webview_load_complete_time"] as! String == paywallInfo.webViewLoadCompleteTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_webview_load_duration"] as? TimeInterval == paywallInfo.webViewLoadDuration)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_start_time"] as! String == paywallInfo.productsLoadStartTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_complete_time"] as! String == paywallInfo.productsLoadCompleteTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_fail_time"] as! String == paywallInfo.productsLoadFailTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_duration"] as? TimeInterval == paywallInfo.productsLoadDuration)
    #expect(
      result.parameters.audienceFilterParams["$is_free_trial_available"] as! Bool == paywallInfo.isFreeTrialAvailable)
    #expect(
      result.parameters.audienceFilterParams["$event_name"] as! String == "paywall_close")
    #expect(result.parameters.audienceFilterParams["$survey_attached"] as! Bool)
    #expect(
      result.parameters.audienceFilterParams["$survey_presentation"] as! String == "holdout")

    // Custom parameters
    #expect(result.parameters.audienceFilterParams["event_name"] as! String == "paywall_close")
    #expect(
      result.parameters.audienceFilterParams["paywall_id"] as! String == paywallInfo.databaseId)
    #expect(
      result.parameters.audienceFilterParams["paywall_name"] as! String == paywallInfo.name)
    #expect(
      result.parameters.audienceFilterParams["is_free_trial_available"] as! Bool == paywallInfo.isFreeTrialAvailable)
    #expect(
      result.parameters.audienceFilterParams["feature_gating"] as! String == FeatureGatingBehavior.nonGated.description)
    #expect(
      result.parameters.audienceFilterParams["presented_by"] as! String == paywallInfo.presentedBy)
    #expect(
      result.parameters.audienceFilterParams["paywall_product_ids"] as? String == paywallInfo.productIds.joined(separator: ","))
    #expect(result.parameters.audienceFilterParams["primary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["secondary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["tertiary_product_id"] != nil)
    #expect(
      result.parameters.audienceFilterParams["presented_by_event_name"] as? String == paywallInfo.presentedByPlacementWithName)
  }

  @Test func paywallClose_noSurvey() async {
    let paywall: Paywall = .stub()
      .setting(\.surveys, to: [])
    let paywallInfo = paywall.getInfo(fromPlacement: .stub())
    let result = await Superwall.shared.track(
      InternalSuperwallEvent.PaywallClose(
        paywallInfo: paywallInfo,
        surveyPresentationResult: .noShow
      )
    )
    #expect(result.parameters.audienceFilterParams["$app_session_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$is_standard_event"] as! Bool)

    #expect(
      result.parameters.audienceFilterParams["$paywall_id"] as! String == paywallInfo.databaseId)
    #expect(
      result.parameters.audienceFilterParams["$paywalljs_version"] as? String ==
      paywallInfo.paywalljsVersion)
    #expect(
      result.parameters.audienceFilterParams["$paywall_identifier"] as! String ==
      paywallInfo.identifier)
    #expect(
      result.parameters.audienceFilterParams["$paywall_name"] as! String == paywallInfo.name)
    #expect(
      result.parameters.audienceFilterParams["$paywall_url"] as! String == paywallInfo.url.absoluteString)
    #expect(
      result.parameters.audienceFilterParams["$presented_by_event_name"] as? String == paywallInfo.presentedByPlacementWithName)
    #expect(
      result.parameters.audienceFilterParams["$presented_by_event_id"] as? String == paywallInfo.presentedByPlacementWithId)
    #expect(
      result.parameters.audienceFilterParams["$presented_by_event_timestamp"] as? String == paywallInfo.presentedByPlacementAt)
    #expect(
      result.parameters.audienceFilterParams["$presented_by"] as! String == paywallInfo.presentedBy)
    #expect(
      result.parameters.audienceFilterParams["$paywall_product_ids"] as? String == paywallInfo.productIds.joined(separator: ","))
    #expect(
      result.parameters.audienceFilterParams["$paywall_response_load_start_time"] as! String == paywallInfo.responseLoadStartTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_response_load_complete_time"] as! String == paywallInfo.responseLoadCompleteTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_response_load_duration"] as? TimeInterval == paywallInfo.responseLoadDuration)
    #expect(
      result.parameters.audienceFilterParams["$paywall_webview_load_start_time"] as! String == paywallInfo.webViewLoadStartTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_webview_load_complete_time"] as! String == paywallInfo.webViewLoadCompleteTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_webview_load_duration"] as? TimeInterval == paywallInfo.webViewLoadDuration)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_start_time"] as! String == paywallInfo.productsLoadStartTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_complete_time"] as! String == paywallInfo.productsLoadCompleteTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_fail_time"] as! String == paywallInfo.productsLoadFailTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_duration"] as? TimeInterval == paywallInfo.productsLoadDuration)
    #expect(
      result.parameters.audienceFilterParams["$is_free_trial_available"] as! Bool == paywallInfo.isFreeTrialAvailable)
    #expect(
      result.parameters.audienceFilterParams["$event_name"] as! String == "paywall_close")
    #expect(!(result.parameters.audienceFilterParams["$survey_attached"] as! Bool))
    #expect(result.parameters.audienceFilterParams["$survey_presentation"] == nil)

    // Custom parameters
    #expect(result.parameters.audienceFilterParams["event_name"] as! String == "paywall_close")
    #expect(
      result.parameters.audienceFilterParams["paywall_id"] as! String == paywallInfo.databaseId)
    #expect(
      result.parameters.audienceFilterParams["paywall_name"] as! String == paywallInfo.name)
    #expect(
      result.parameters.audienceFilterParams["is_free_trial_available"] as! Bool == paywallInfo.isFreeTrialAvailable)
    #expect(
      result.parameters.audienceFilterParams["feature_gating"] as! String == FeatureGatingBehavior.nonGated.description)
    #expect(
      result.parameters.audienceFilterParams["presented_by"] as! String == paywallInfo.presentedBy)
    #expect(
      result.parameters.audienceFilterParams["paywall_product_ids"] as? String == paywallInfo.productIds.joined(separator: ","))
    #expect(result.parameters.audienceFilterParams["primary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["secondary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["tertiary_product_id"] != nil)
    #expect(
      result.parameters.audienceFilterParams["presented_by_event_name"] as? String == paywallInfo.presentedByPlacementWithName)
  }

  @Test func paywallDecline() async {
    let paywallInfo: PaywallInfo = .stub()
    let result = await Superwall.shared.track(
      InternalSuperwallEvent.PaywallDecline(paywallInfo: paywallInfo))
    #expect(result.parameters.audienceFilterParams["$app_session_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$is_standard_event"] as! Bool)

    #expect(
      result.parameters.audienceFilterParams["$paywall_id"] as! String == paywallInfo.databaseId)
    #expect(
      result.parameters.audienceFilterParams["$paywalljs_version"] as? String ==
      paywallInfo.paywalljsVersion)
    #expect(
      result.parameters.audienceFilterParams["$paywall_identifier"] as! String ==
      paywallInfo.identifier)
    #expect(
      result.parameters.audienceFilterParams["$paywall_name"] as! String == paywallInfo.name)
    #expect(
      result.parameters.audienceFilterParams["$paywall_url"] as! String == paywallInfo.url.absoluteString)
    #expect(
      result.parameters.audienceFilterParams["$presented_by_event_name"] as? String == paywallInfo.presentedByPlacementWithName)
    #expect(
      result.parameters.audienceFilterParams["$presented_by_event_id"] as? String == paywallInfo.presentedByPlacementWithId)
    #expect(
      result.parameters.audienceFilterParams["$presented_by_event_timestamp"] as? String == paywallInfo.presentedByPlacementAt)
    #expect(
      result.parameters.audienceFilterParams["$presented_by"] as! String == paywallInfo.presentedBy)
    #expect(
      result.parameters.audienceFilterParams["$paywall_product_ids"] as? String == paywallInfo.productIds.joined(separator: ","))
    #expect(
      result.parameters.audienceFilterParams["$paywall_response_load_start_time"] as! String == paywallInfo.responseLoadStartTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_response_load_complete_time"] as! String == paywallInfo.responseLoadCompleteTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_response_load_duration"] as? TimeInterval == paywallInfo.responseLoadDuration)
    #expect(
      result.parameters.audienceFilterParams["$paywall_webview_load_start_time"] as! String == paywallInfo.webViewLoadStartTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_webview_load_complete_time"] as! String == paywallInfo.webViewLoadCompleteTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_webview_load_duration"] as? TimeInterval == paywallInfo.webViewLoadDuration)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_start_time"] as! String == paywallInfo.productsLoadStartTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_complete_time"] as! String == paywallInfo.productsLoadCompleteTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_fail_time"] as! String == paywallInfo.productsLoadFailTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_duration"] as? TimeInterval == paywallInfo.productsLoadDuration)
    #expect(
      result.parameters.audienceFilterParams["$is_free_trial_available"] as! Bool == paywallInfo.isFreeTrialAvailable)
    #expect(
      result.parameters.audienceFilterParams["$event_name"] as! String == "paywall_decline")

    // Custom parameters
    #expect(
      result.parameters.audienceFilterParams["event_name"] as! String == "paywall_decline")
    #expect(
      result.parameters.audienceFilterParams["paywall_id"] as! String == paywallInfo.databaseId)
    #expect(
      result.parameters.audienceFilterParams["paywall_name"] as! String == paywallInfo.name)
    #expect(
      result.parameters.audienceFilterParams["is_free_trial_available"] as! Bool == paywallInfo.isFreeTrialAvailable)
    #expect(
      result.parameters.audienceFilterParams["feature_gating"] as! String == FeatureGatingBehavior.nonGated.description)
    #expect(
      result.parameters.audienceFilterParams["presented_by"] as! String == paywallInfo.presentedBy)
    #expect(
      result.parameters.audienceFilterParams["paywall_product_ids"] as? String == paywallInfo.productIds.joined(separator: ","))
    #expect(result.parameters.audienceFilterParams["primary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["secondary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["tertiary_product_id"] != nil)
    #expect(
      result.parameters.audienceFilterParams["presented_by_event_name"] as? String == paywallInfo.presentedByPlacementWithName)
  }

  @Test func transaction_start() async {
    let paywallInfo: PaywallInfo = .stub()
    let productId = "abc"
    let product = StoreProduct(
      sk1Product: MockSkProduct(productIdentifier: productId),
      entitlements: [.stub()]
    )
    let dependencyContainer = DependencyContainer()
    let skTransaction = MockSKPaymentTransaction(state: .purchased)
    let transaction = await dependencyContainer.makeStoreTransaction(from: skTransaction)
    let result = await Superwall.shared.track(
      InternalSuperwallEvent.Transaction(
        state: .start(product), paywallInfo: paywallInfo, product: product,
        transaction: transaction, source: .internal, isObserved: false, storeKitVersion: .storeKit1)
    )
    #expect(result.parameters.audienceFilterParams["$app_session_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$is_standard_event"] as! Bool)

    #expect(result.parameters.audienceFilterParams["$source"] as! String == "SUPERWALL")
    #expect(result.parameters.audienceFilterParams["$store"] as! String == "APP_STORE")
    #expect(
      result.parameters.audienceFilterParams["$storekit_version"] as! String == "STOREKIT1")
    #expect(
      result.parameters.audienceFilterParams["$paywall_id"] as! String == paywallInfo.databaseId)
    #expect(
      result.parameters.audienceFilterParams["$paywalljs_version"] as? String ==
      paywallInfo.paywalljsVersion)
    #expect(
      result.parameters.audienceFilterParams["$paywall_identifier"] as! String ==
      paywallInfo.identifier)
    #expect(
      result.parameters.audienceFilterParams["$paywall_name"] as! String == paywallInfo.name)
    #expect(
      result.parameters.audienceFilterParams["$paywall_url"] as! String == paywallInfo.url.absoluteString)
    #expect(
      result.parameters.audienceFilterParams["$presented_by_event_name"] as? String == paywallInfo.presentedByPlacementWithName)
    #expect(
      result.parameters.audienceFilterParams["$presented_by_event_id"] as? String == paywallInfo.presentedByPlacementWithId)
    #expect(
      result.parameters.audienceFilterParams["$presented_by_event_timestamp"] as? String == paywallInfo.presentedByPlacementAt)
    #expect(
      result.parameters.audienceFilterParams["$presented_by"] as! String == paywallInfo.presentedBy)
    #expect(
      result.parameters.audienceFilterParams["$paywall_product_ids"] as? String == paywallInfo.productIds.joined(separator: ","))
    #expect(
      result.parameters.audienceFilterParams["$paywall_response_load_start_time"] as! String == paywallInfo.responseLoadStartTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_response_load_complete_time"] as! String == paywallInfo.responseLoadCompleteTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_response_load_duration"] as? TimeInterval == paywallInfo.responseLoadDuration)
    #expect(
      result.parameters.audienceFilterParams["$paywall_webview_load_start_time"] as! String == paywallInfo.webViewLoadStartTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_webview_load_complete_time"] as! String == paywallInfo.webViewLoadCompleteTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_webview_load_duration"] as? TimeInterval == paywallInfo.webViewLoadDuration)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_start_time"] as! String == paywallInfo.productsLoadStartTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_complete_time"] as! String == paywallInfo.productsLoadCompleteTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_fail_time"] as! String == paywallInfo.productsLoadFailTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_duration"] as? TimeInterval == paywallInfo.productsLoadDuration)
    #expect(
      result.parameters.audienceFilterParams["$is_free_trial_available"] as! Bool == paywallInfo.isFreeTrialAvailable)
    #expect(result.parameters.audienceFilterParams["$product_id"] as! String == productId)
    #expect(
      result.parameters.audienceFilterParams["$product_identifier"] as! String == productId)
    #expect(result.parameters.audienceFilterParams["$product_raw_price"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_price"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_period_alt"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_localized_period"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_period"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_periodly"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_weekly_price"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_daily_price"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_monthly_price"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_yearly_price"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_trial_period_days"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_trial_period_weeks"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_trial_period_months"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_trial_period_years"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_trial_period_text"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_trial_period_end_date"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_period_days"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_period_weeks"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_period_months"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_period_years"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_locale"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_language_code"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_currency_code"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_currency_symbol"] != nil)
    #expect(result.parameters.audienceFilterParams["$primary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$secondary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$tertiary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$original_transaction_identifier"] != nil)
    #expect(result.parameters.audienceFilterParams["$config_request_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$state"] as! String == "PURCHASED")
    #expect(result.parameters.audienceFilterParams["$id"] != nil)
    #expect(result.parameters.audienceFilterParams["$app_session_id"] != nil)
    #expect(
      result.parameters.audienceFilterParams["$event_name"] as! String == "transaction_start")

    // Custom parameters
    #expect(
      result.parameters.audienceFilterParams["event_name"] as! String == "transaction_start")
    #expect(
      result.parameters.audienceFilterParams["paywall_id"] as! String == paywallInfo.databaseId)
    #expect(
      result.parameters.audienceFilterParams["paywall_name"] as! String == paywallInfo.name)
    #expect(
      result.parameters.audienceFilterParams["is_free_trial_available"] as! Bool == paywallInfo.isFreeTrialAvailable)
    #expect(
      result.parameters.audienceFilterParams["feature_gating"] as! String == FeatureGatingBehavior.nonGated.description)
    #expect(
      result.parameters.audienceFilterParams["presented_by"] as! String == paywallInfo.presentedBy)
    #expect(
      result.parameters.audienceFilterParams["paywall_product_ids"] as? String == paywallInfo.productIds.joined(separator: ","))
    #expect(result.parameters.audienceFilterParams["primary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["secondary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["tertiary_product_id"] != nil)
    #expect(
      result.parameters.audienceFilterParams["presented_by_event_name"] as? String == paywallInfo.presentedByPlacementWithName)
  }

  @Test func transaction_complete() async {
    let paywallInfo: PaywallInfo = .stub()
    let productId = "abc"
    let product = StoreProduct(
      sk1Product: MockSkProduct(productIdentifier: productId),
      entitlements: [.stub()]
    )
    let dependencyContainer = DependencyContainer()
    let skTransaction = MockSKPaymentTransaction(state: .purchased)
    let transaction = await dependencyContainer.makeStoreTransaction(from: skTransaction)
    let result = await Superwall.shared.track(
      InternalSuperwallEvent.Transaction(
        state: .complete(product, transaction, .nonRecurringProductPurchase),
        paywallInfo: paywallInfo,
        product: product,
        transaction: transaction,
        source: .internal,
        isObserved: false,
        storeKitVersion: .storeKit1,
          demandScore: 80,
          demandTier: "Platinum"
        )
    )
    #expect(result.parameters.audienceFilterParams["$app_session_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$is_standard_event"] as! Bool)

    #expect(result.parameters.audienceFilterParams["$source"] as! String == "SUPERWALL")
    #expect(result.parameters.audienceFilterParams["$store"] as! String == "APP_STORE")
    #expect(
      result.parameters.audienceFilterParams["$storekit_version"] as! String == "STOREKIT1")
    #expect(
      result.parameters.audienceFilterParams["$transaction_type"] as! String == "NON_RECURRING_PRODUCT_PURCHASE")
    #expect(
      result.parameters.audienceFilterParams["$paywall_id"] as! String == paywallInfo.databaseId)
    #expect(
      result.parameters.audienceFilterParams["$paywalljs_version"] as? String ==
      paywallInfo.paywalljsVersion)
    #expect(
      result.parameters.audienceFilterParams["$paywall_identifier"] as! String ==
      paywallInfo.identifier)
    #expect(
      result.parameters.audienceFilterParams["$paywall_name"] as! String == paywallInfo.name)
    #expect(
      result.parameters.audienceFilterParams["$paywall_url"] as! String == paywallInfo.url.absoluteString)
    #expect(
      result.parameters.audienceFilterParams["$presented_by_event_name"] as? String == paywallInfo.presentedByPlacementWithName)
    #expect(
      result.parameters.audienceFilterParams["$presented_by_event_id"] as? String == paywallInfo.presentedByPlacementWithId)
    #expect(
      result.parameters.audienceFilterParams["$presented_by_event_timestamp"] as? String == paywallInfo.presentedByPlacementAt)
    #expect(
      result.parameters.audienceFilterParams["$presented_by"] as! String == paywallInfo.presentedBy)
    #expect(
      result.parameters.audienceFilterParams["$paywall_product_ids"] as? String == paywallInfo.productIds.joined(separator: ","))
    #expect(
      result.parameters.audienceFilterParams["$paywall_response_load_start_time"] as! String == paywallInfo.responseLoadStartTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_response_load_complete_time"] as! String == paywallInfo.responseLoadCompleteTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_response_load_duration"] as? TimeInterval == paywallInfo.responseLoadDuration)
    #expect(
      result.parameters.audienceFilterParams["$paywall_webview_load_start_time"] as! String == paywallInfo.webViewLoadStartTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_webview_load_complete_time"] as! String == paywallInfo.webViewLoadCompleteTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_webview_load_duration"] as? TimeInterval == paywallInfo.webViewLoadDuration)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_start_time"] as! String == paywallInfo.productsLoadStartTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_complete_time"] as! String == paywallInfo.productsLoadCompleteTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_fail_time"] as! String == paywallInfo.productsLoadFailTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_duration"] as? TimeInterval == paywallInfo.productsLoadDuration)
    #expect(
      result.parameters.audienceFilterParams["$is_free_trial_available"] as! Bool == paywallInfo.isFreeTrialAvailable)
    #expect(result.parameters.audienceFilterParams["$attr_demandScore"] as! Int == 80)
    #expect(result.parameters.audienceFilterParams["$attr_demandTier"] as! String == "Platinum")
    #expect(result.parameters.audienceFilterParams["$product_id"] as! String == productId)
    #expect(
      result.parameters.audienceFilterParams["$product_identifier"] as! String == productId)
    #expect(result.parameters.audienceFilterParams["$product_raw_price"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_price"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_period_alt"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_localized_period"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_period"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_periodly"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_weekly_price"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_daily_price"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_monthly_price"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_yearly_price"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_trial_period_days"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_trial_period_weeks"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_trial_period_months"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_trial_period_years"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_trial_period_text"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_trial_period_end_date"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_period_days"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_period_weeks"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_period_months"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_period_years"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_locale"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_language_code"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_currency_code"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_currency_symbol"] != nil)
    #expect(result.parameters.audienceFilterParams["$primary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$secondary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$tertiary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$original_transaction_identifier"] != nil)
    #expect(result.parameters.audienceFilterParams["$config_request_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$state"] as! String == "PURCHASED")
    #expect(result.parameters.audienceFilterParams["$id"] != nil)
    #expect(result.parameters.audienceFilterParams["$app_session_id"] != nil)
    #expect(
      result.parameters.audienceFilterParams["$event_name"] as! String == "transaction_complete")

    // Custom parameters
    #expect(
      result.parameters.audienceFilterParams["event_name"] as! String == "transaction_complete")
    #expect(
      result.parameters.audienceFilterParams["paywall_id"] as! String == paywallInfo.databaseId)
    #expect(
      result.parameters.audienceFilterParams["paywall_name"] as! String == paywallInfo.name)
    #expect(
      result.parameters.audienceFilterParams["is_free_trial_available"] as! Bool == paywallInfo.isFreeTrialAvailable)
    #expect(
      result.parameters.audienceFilterParams["feature_gating"] as! String == FeatureGatingBehavior.nonGated.description)
    #expect(
      result.parameters.audienceFilterParams["presented_by"] as! String == paywallInfo.presentedBy)
    #expect(
      result.parameters.audienceFilterParams["paywall_product_ids"] as? String == paywallInfo.productIds.joined(separator: ","))
    #expect(result.parameters.audienceFilterParams["primary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["secondary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["tertiary_product_id"] != nil)
    #expect(
      result.parameters.audienceFilterParams["presented_by_event_name"] as? String == paywallInfo.presentedByPlacementWithName)
  }

  @Test func transaction_restore() async {
    let paywallInfo: PaywallInfo = .stub()
    let productId = "abc"
    let product = StoreProduct(
      sk1Product: MockSkProduct(productIdentifier: productId),
      entitlements: [.stub()]
    )
    let dependencyContainer = DependencyContainer()
    let skTransaction = MockSKPaymentTransaction(state: .purchased)
    let transaction = await dependencyContainer.makeStoreTransaction(from: skTransaction)
    let result = await Superwall.shared.track(
      InternalSuperwallEvent.Transaction(
        state: .restore(RestoreType.viaPurchase(transaction)), paywallInfo: paywallInfo,
        product: product, transaction: transaction, source: .internal, isObserved: false,
        storeKitVersion: .storeKit2))
    #expect(result.parameters.audienceFilterParams["$app_session_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$is_standard_event"] as! Bool)

    #expect(result.parameters.audienceFilterParams["$source"] as! String == "SUPERWALL")
    #expect(result.parameters.audienceFilterParams["$store"] as! String == "APP_STORE")
    #expect(
      result.parameters.audienceFilterParams["$storekit_version"] as! String == "STOREKIT2")
    #expect(
      result.parameters.audienceFilterParams["$paywall_id"] as! String == paywallInfo.databaseId)
    #expect(result.parameters.audienceFilterParams["$restore_via_purchase_attempt"] as! Bool)
    #expect(
      result.parameters.audienceFilterParams["$paywalljs_version"] as? String ==
      paywallInfo.paywalljsVersion)
    #expect(
      result.parameters.audienceFilterParams["$paywall_identifier"] as! String ==
      paywallInfo.identifier)
    #expect(
      result.parameters.audienceFilterParams["$paywall_name"] as! String == paywallInfo.name)
    #expect(
      result.parameters.audienceFilterParams["$paywall_url"] as! String == paywallInfo.url.absoluteString)
    #expect(
      result.parameters.audienceFilterParams["$presented_by_event_name"] as? String == paywallInfo.presentedByPlacementWithName)
    #expect(
      result.parameters.audienceFilterParams["$presented_by_event_id"] as? String == paywallInfo.presentedByPlacementWithId)
    #expect(
      result.parameters.audienceFilterParams["$presented_by_event_timestamp"] as? String == paywallInfo.presentedByPlacementAt)
    #expect(
      result.parameters.audienceFilterParams["$presented_by"] as! String == paywallInfo.presentedBy)
    #expect(
      result.parameters.audienceFilterParams["$paywall_product_ids"] as? String == paywallInfo.productIds.joined(separator: ","))
    #expect(
      result.parameters.audienceFilterParams["$paywall_response_load_start_time"] as! String == paywallInfo.responseLoadStartTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_response_load_complete_time"] as! String == paywallInfo.responseLoadCompleteTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_response_load_duration"] as? TimeInterval == paywallInfo.responseLoadDuration)
    #expect(
      result.parameters.audienceFilterParams["$paywall_webview_load_start_time"] as! String == paywallInfo.webViewLoadStartTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_webview_load_complete_time"] as! String == paywallInfo.webViewLoadCompleteTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_webview_load_duration"] as? TimeInterval == paywallInfo.webViewLoadDuration)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_start_time"] as! String == paywallInfo.productsLoadStartTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_complete_time"] as! String == paywallInfo.productsLoadCompleteTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_fail_time"] as! String == paywallInfo.productsLoadFailTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_duration"] as? TimeInterval == paywallInfo.productsLoadDuration)
    #expect(
      result.parameters.audienceFilterParams["$is_free_trial_available"] as! Bool == paywallInfo.isFreeTrialAvailable)
    #expect(result.parameters.audienceFilterParams["$product_id"] as! String == productId)
    #expect(
      result.parameters.audienceFilterParams["$product_identifier"] as! String == productId)
    #expect(result.parameters.audienceFilterParams["$product_raw_price"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_price"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_period_alt"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_localized_period"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_period"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_periodly"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_weekly_price"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_daily_price"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_monthly_price"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_yearly_price"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_trial_period_days"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_trial_period_weeks"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_trial_period_months"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_trial_period_years"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_trial_period_text"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_trial_period_end_date"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_period_days"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_period_weeks"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_period_months"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_period_years"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_locale"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_language_code"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_currency_code"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_currency_symbol"] != nil)
    #expect(result.parameters.audienceFilterParams["$primary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$secondary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$tertiary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$original_transaction_identifier"] != nil)
    #expect(result.parameters.audienceFilterParams["$config_request_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$state"] as! String == "PURCHASED")
    #expect(result.parameters.audienceFilterParams["$id"] != nil)
    #expect(result.parameters.audienceFilterParams["$app_session_id"] != nil)
    #expect(
      result.parameters.audienceFilterParams["$event_name"] as! String == "transaction_restore")

    // Custom parameters
    #expect(
      result.parameters.audienceFilterParams["event_name"] as! String == "transaction_restore")
    #expect(
      result.parameters.audienceFilterParams["paywall_id"] as! String == paywallInfo.databaseId)
    #expect(
      result.parameters.audienceFilterParams["paywall_name"] as! String == paywallInfo.name)
    #expect(
      result.parameters.audienceFilterParams["is_free_trial_available"] as! Bool == paywallInfo.isFreeTrialAvailable)
    #expect(
      result.parameters.audienceFilterParams["feature_gating"] as! String == FeatureGatingBehavior.nonGated.description)
    #expect(
      result.parameters.audienceFilterParams["presented_by"] as! String == paywallInfo.presentedBy)
    #expect(
      result.parameters.audienceFilterParams["paywall_product_ids"] as? String == paywallInfo.productIds.joined(separator: ","))
    #expect(result.parameters.audienceFilterParams["primary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["secondary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["tertiary_product_id"] != nil)
    #expect(
      result.parameters.audienceFilterParams["presented_by_event_name"] as? String == paywallInfo.presentedByPlacementWithName)
  }

  @Test func transaction_timeout() async {
    let paywallInfo: PaywallInfo = .stub()
    let productId = "abc"
    let product = StoreProduct(
      sk1Product: MockSkProduct(productIdentifier: productId),
      entitlements: [.stub()]
    )
    let dependencyContainer = DependencyContainer()
    let skTransaction = MockSKPaymentTransaction(state: .purchased)
    let transaction = await dependencyContainer.makeStoreTransaction(from: skTransaction)
    let result = await Superwall.shared.track(
      InternalSuperwallEvent.Transaction(
        state: .timeout, paywallInfo: paywallInfo, product: product, transaction: transaction,
        source: .internal, isObserved: false, storeKitVersion: .storeKit1))
    #expect(result.parameters.audienceFilterParams["$app_session_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$is_standard_event"] as! Bool)

    #expect(result.parameters.audienceFilterParams["$source"] as! String == "SUPERWALL")
    #expect(result.parameters.audienceFilterParams["$store"] as! String == "APP_STORE")
    #expect(
      result.parameters.audienceFilterParams["$storekit_version"] as! String == "STOREKIT1")
    #expect(
      result.parameters.audienceFilterParams["$paywall_id"] as! String == paywallInfo.databaseId)
    #expect(
      result.parameters.audienceFilterParams["$paywalljs_version"] as? String ==
      paywallInfo.paywalljsVersion)
    #expect(
      result.parameters.audienceFilterParams["$paywall_identifier"] as! String ==
      paywallInfo.identifier)
    #expect(
      result.parameters.audienceFilterParams["$paywall_name"] as! String == paywallInfo.name)
    #expect(
      result.parameters.audienceFilterParams["$paywall_url"] as! String == paywallInfo.url.absoluteString)
    #expect(
      result.parameters.audienceFilterParams["$presented_by_event_name"] as? String == paywallInfo.presentedByPlacementWithName)
    #expect(
      result.parameters.audienceFilterParams["$presented_by_event_id"] as? String == paywallInfo.presentedByPlacementWithId)
    #expect(
      result.parameters.audienceFilterParams["$presented_by_event_timestamp"] as? String == paywallInfo.presentedByPlacementAt)
    #expect(
      result.parameters.audienceFilterParams["$presented_by"] as! String == paywallInfo.presentedBy)
    #expect(
      result.parameters.audienceFilterParams["$paywall_product_ids"] as? String == paywallInfo.productIds.joined(separator: ","))
    #expect(
      result.parameters.audienceFilterParams["$paywall_response_load_start_time"] as! String == paywallInfo.responseLoadStartTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_response_load_complete_time"] as! String == paywallInfo.responseLoadCompleteTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_response_load_duration"] as? TimeInterval == paywallInfo.responseLoadDuration)
    #expect(
      result.parameters.audienceFilterParams["$paywall_webview_load_start_time"] as! String == paywallInfo.webViewLoadStartTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_webview_load_complete_time"] as! String == paywallInfo.webViewLoadCompleteTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_webview_load_duration"] as? TimeInterval == paywallInfo.webViewLoadDuration)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_start_time"] as! String == paywallInfo.productsLoadStartTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_complete_time"] as! String == paywallInfo.productsLoadCompleteTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_fail_time"] as! String == paywallInfo.productsLoadFailTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_duration"] as? TimeInterval == paywallInfo.productsLoadDuration)
    #expect(
      result.parameters.audienceFilterParams["$is_free_trial_available"] as! Bool == paywallInfo.isFreeTrialAvailable)
    #expect(result.parameters.audienceFilterParams["$product_id"] as! String == productId)
    #expect(
      result.parameters.audienceFilterParams["$product_identifier"] as! String == productId)
    #expect(result.parameters.audienceFilterParams["$product_raw_price"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_price"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_period_alt"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_localized_period"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_period"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_periodly"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_weekly_price"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_daily_price"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_monthly_price"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_yearly_price"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_trial_period_days"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_trial_period_weeks"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_trial_period_months"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_trial_period_years"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_trial_period_text"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_trial_period_end_date"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_period_days"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_period_weeks"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_period_months"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_period_years"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_locale"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_language_code"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_currency_code"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_currency_symbol"] != nil)
    #expect(result.parameters.audienceFilterParams["$primary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$secondary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$tertiary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$original_transaction_identifier"] != nil)
    #expect(result.parameters.audienceFilterParams["$config_request_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$state"] as! String == "PURCHASED")
    #expect(result.parameters.audienceFilterParams["$id"] != nil)
    #expect(result.parameters.audienceFilterParams["$app_session_id"] != nil)
    #expect(
      result.parameters.audienceFilterParams["$event_name"] as! String == "transaction_timeout")

    // Custom parameters
    #expect(
      result.parameters.audienceFilterParams["event_name"] as! String == "transaction_timeout")
    #expect(
      result.parameters.audienceFilterParams["paywall_id"] as! String == paywallInfo.databaseId)
    #expect(
      result.parameters.audienceFilterParams["paywall_name"] as! String == paywallInfo.name)
    #expect(
      result.parameters.audienceFilterParams["is_free_trial_available"] as! Bool == paywallInfo.isFreeTrialAvailable)
    #expect(
      result.parameters.audienceFilterParams["feature_gating"] as! String == FeatureGatingBehavior.nonGated.description)
    #expect(
      result.parameters.audienceFilterParams["presented_by"] as! String == paywallInfo.presentedBy)
    #expect(
      result.parameters.audienceFilterParams["paywall_product_ids"] as? String == paywallInfo.productIds.joined(separator: ","))
    #expect(result.parameters.audienceFilterParams["primary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["secondary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["tertiary_product_id"] != nil)
    #expect(
      result.parameters.audienceFilterParams["presented_by_event_name"] as? String == paywallInfo.presentedByPlacementWithName)
  }

  @Test func transaction_fail() async {
    let paywallInfo: PaywallInfo = .stub()
    let productId = "abc"
    let product = StoreProduct(
      sk1Product: MockSkProduct(productIdentifier: productId),
      entitlements: [.stub()]
    )
    let dependencyContainer = DependencyContainer()
    let skTransaction = MockSKPaymentTransaction(state: .purchased)
    let transaction = await dependencyContainer.makeStoreTransaction(from: skTransaction)
    let error = TransactionError.failure("failed mate", product)
    let result = await Superwall.shared.track(
      InternalSuperwallEvent.Transaction(
        state: .fail(error), paywallInfo: paywallInfo, product: product, transaction: transaction,
        source: .external, isObserved: false, storeKitVersion: .storeKit1))
    #expect(result.parameters.audienceFilterParams["$app_session_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$is_standard_event"] as! Bool)

    #expect(result.parameters.audienceFilterParams["$source"] as! String == "APP")
    #expect(result.parameters.audienceFilterParams["$store"] as! String == "APP_STORE")
    #expect(
      result.parameters.audienceFilterParams["$storekit_version"] as! String == "STOREKIT1")
    #expect(
      result.parameters.audienceFilterParams["$paywall_id"] as! String == paywallInfo.databaseId)
    #expect(
      result.parameters.audienceFilterParams["$paywalljs_version"] as? String ==
      paywallInfo.paywalljsVersion)
    #expect(
      result.parameters.audienceFilterParams["$paywall_identifier"] as! String ==
      paywallInfo.identifier)
    #expect(
      result.parameters.audienceFilterParams["$paywall_name"] as! String == paywallInfo.name)
    #expect(
      result.parameters.audienceFilterParams["$paywall_url"] as! String == paywallInfo.url.absoluteString)
    #expect(
      result.parameters.audienceFilterParams["$presented_by_event_name"] as? String == paywallInfo.presentedByPlacementWithName)
    #expect(
      result.parameters.audienceFilterParams["$presented_by_event_id"] as? String == paywallInfo.presentedByPlacementWithId)
    #expect(
      result.parameters.audienceFilterParams["$presented_by_event_timestamp"] as? String == paywallInfo.presentedByPlacementAt)
    #expect(
      result.parameters.audienceFilterParams["$presented_by"] as! String == paywallInfo.presentedBy)
    #expect(
      result.parameters.audienceFilterParams["$paywall_product_ids"] as? String == paywallInfo.productIds.joined(separator: ","))
    #expect(
      result.parameters.audienceFilterParams["$paywall_response_load_start_time"] as! String == paywallInfo.responseLoadStartTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_response_load_complete_time"] as! String == paywallInfo.responseLoadCompleteTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_response_load_duration"] as? TimeInterval == paywallInfo.responseLoadDuration)
    #expect(
      result.parameters.audienceFilterParams["$paywall_webview_load_start_time"] as! String == paywallInfo.webViewLoadStartTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_webview_load_complete_time"] as! String == paywallInfo.webViewLoadCompleteTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_webview_load_duration"] as? TimeInterval == paywallInfo.webViewLoadDuration)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_start_time"] as! String == paywallInfo.productsLoadStartTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_complete_time"] as! String == paywallInfo.productsLoadCompleteTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_fail_time"] as! String == paywallInfo.productsLoadFailTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_duration"] as? TimeInterval == paywallInfo.productsLoadDuration)
    #expect(
      result.parameters.audienceFilterParams["$is_free_trial_available"] as! Bool == paywallInfo.isFreeTrialAvailable)
    #expect(result.parameters.audienceFilterParams["$product_id"] as! String == productId)
    #expect(
      result.parameters.audienceFilterParams["$product_identifier"] as! String == productId)
    #expect(result.parameters.audienceFilterParams["$product_raw_price"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_price"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_period_alt"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_localized_period"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_period"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_periodly"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_weekly_price"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_daily_price"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_monthly_price"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_yearly_price"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_trial_period_days"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_trial_period_weeks"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_trial_period_months"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_trial_period_years"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_trial_period_text"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_trial_period_end_date"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_period_days"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_period_weeks"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_period_months"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_period_years"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_locale"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_language_code"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_currency_code"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_currency_symbol"] != nil)
    #expect(result.parameters.audienceFilterParams["$primary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$secondary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$tertiary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$app_session_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$message"] as! String == "failed mate")
    #expect(
      result.parameters.audienceFilterParams["$event_name"] as! String == "transaction_fail")

    // Custom parameters
    #expect(
      result.parameters.audienceFilterParams["event_name"] as! String == "transaction_fail")
    #expect(
      result.parameters.audienceFilterParams["paywall_id"] as! String == paywallInfo.databaseId)
    #expect(
      result.parameters.audienceFilterParams["paywall_name"] as! String == paywallInfo.name)
    #expect(
      result.parameters.audienceFilterParams["is_free_trial_available"] as! Bool == paywallInfo.isFreeTrialAvailable)
    #expect(
      result.parameters.audienceFilterParams["feature_gating"] as! String == FeatureGatingBehavior.nonGated.description)
    #expect(
      result.parameters.audienceFilterParams["presented_by"] as! String == paywallInfo.presentedBy)
    #expect(
      result.parameters.audienceFilterParams["paywall_product_ids"] as? String == paywallInfo.productIds.joined(separator: ","))
    #expect(result.parameters.audienceFilterParams["primary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["secondary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["tertiary_product_id"] != nil)
    #expect(
      result.parameters.audienceFilterParams["presented_by_event_name"] as? String == paywallInfo.presentedByPlacementWithName)
  }

  @Test func subscriptionStart() async {
    let paywallInfo: PaywallInfo = .stub()
    let productId = "abc"
    let product = StoreProduct(
      sk1Product: MockSkProduct(productIdentifier: productId),
      entitlements: [.stub()]
    )
    let skTransaction = MockSKPaymentTransaction(state: .purchased)
    let dependencyContainer = DependencyContainer()
    let transaction = await dependencyContainer.makeStoreTransaction(from: skTransaction)
    let result = await Superwall.shared.track(
      InternalSuperwallEvent.SubscriptionStart(
        paywallInfo: paywallInfo, product: product, transaction: transaction))
    #expect(result.parameters.audienceFilterParams["$app_session_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$is_standard_event"] as! Bool)
    #expect(
      result.parameters.audienceFilterParams["$event_name"] as! String == "subscription_start")
    #expect(
      result.parameters.audienceFilterParams["$paywall_id"] as! String == paywallInfo.databaseId)
    #expect(
      result.parameters.audienceFilterParams["$paywalljs_version"] as? String ==
      paywallInfo.paywalljsVersion)
    #expect(
      result.parameters.audienceFilterParams["$paywall_identifier"] as! String ==
      paywallInfo.identifier)
    #expect(
      result.parameters.audienceFilterParams["$paywall_name"] as! String == paywallInfo.name)
    #expect(
      result.parameters.audienceFilterParams["$paywall_url"] as! String == paywallInfo.url.absoluteString)
    #expect(
      result.parameters.audienceFilterParams["$presented_by_event_name"] as? String == paywallInfo.presentedByPlacementWithName)
    #expect(
      result.parameters.audienceFilterParams["$presented_by_event_id"] as? String == paywallInfo.presentedByPlacementWithId)
    #expect(
      result.parameters.audienceFilterParams["$presented_by_event_timestamp"] as? String == paywallInfo.presentedByPlacementAt)
    #expect(
      result.parameters.audienceFilterParams["$presented_by"] as! String == paywallInfo.presentedBy)
    #expect(
      result.parameters.audienceFilterParams["$paywall_product_ids"] as? String == paywallInfo.productIds.joined(separator: ","))
    #expect(
      result.parameters.audienceFilterParams["$paywall_response_load_start_time"] as! String == paywallInfo.responseLoadStartTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_response_load_complete_time"] as! String == paywallInfo.responseLoadCompleteTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_response_load_duration"] as? TimeInterval == paywallInfo.responseLoadDuration)
    #expect(
      result.parameters.audienceFilterParams["$paywall_webview_load_start_time"] as! String == paywallInfo.webViewLoadStartTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_webview_load_complete_time"] as! String == paywallInfo.webViewLoadCompleteTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_webview_load_duration"] as? TimeInterval == paywallInfo.webViewLoadDuration)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_start_time"] as! String == paywallInfo.productsLoadStartTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_complete_time"] as! String == paywallInfo.productsLoadCompleteTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_fail_time"] as! String == paywallInfo.productsLoadFailTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_duration"] as? TimeInterval == paywallInfo.productsLoadDuration)
    #expect(
      result.parameters.audienceFilterParams["$is_free_trial_available"] as! Bool == paywallInfo.isFreeTrialAvailable)
    #expect(result.parameters.audienceFilterParams["$product_id"] as! String == productId)
    #expect(
      result.parameters.audienceFilterParams["$product_identifier"] as! String == productId)
    #expect(result.parameters.audienceFilterParams["$product_raw_price"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_price"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_period_alt"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_localized_period"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_period"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_periodly"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_weekly_price"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_daily_price"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_monthly_price"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_yearly_price"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_trial_period_days"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_trial_period_weeks"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_trial_period_months"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_trial_period_years"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_trial_period_text"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_trial_period_end_date"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_period_days"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_period_weeks"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_period_months"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_period_years"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_locale"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_language_code"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_currency_code"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_currency_symbol"] != nil)
    #expect(result.parameters.audienceFilterParams["$primary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$secondary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$tertiary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$app_session_id"] != nil)

    // Custom parameters
    #expect(
      result.parameters.audienceFilterParams["event_name"] as! String == "subscription_start")
    #expect(
      result.parameters.audienceFilterParams["paywall_id"] as! String == paywallInfo.databaseId)
    #expect(
      result.parameters.audienceFilterParams["paywall_name"] as! String == paywallInfo.name)
    #expect(
      result.parameters.audienceFilterParams["is_free_trial_available"] as! Bool == paywallInfo.isFreeTrialAvailable)
    #expect(
      result.parameters.audienceFilterParams["feature_gating"] as! String == FeatureGatingBehavior.nonGated.description)
    #expect(
      result.parameters.audienceFilterParams["presented_by"] as! String == paywallInfo.presentedBy)
    #expect(
      result.parameters.audienceFilterParams["paywall_product_ids"] as? String == paywallInfo.productIds.joined(separator: ","))
    #expect(result.parameters.audienceFilterParams["primary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["secondary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["tertiary_product_id"] != nil)
    #expect(
      result.parameters.audienceFilterParams["presented_by_event_name"] as? String == paywallInfo.presentedByPlacementWithName)
  }

  @Test func freeTrialStart() async {
    let paywallInfo: PaywallInfo = .stub()
    let productId = "abc"
    let product = StoreProduct(
      sk1Product: MockSkProduct(productIdentifier: productId),
      entitlements: [.stub()]
    )
    let skTransaction = MockSKPaymentTransaction(state: .purchased)
    let dependencyContainer = DependencyContainer()
    let transaction = await dependencyContainer.makeStoreTransaction(from: skTransaction)
    let result = await Superwall.shared.track(
      InternalSuperwallEvent.FreeTrialStart(
        paywallInfo: paywallInfo, product: product, transaction: transaction))
    #expect(result.parameters.audienceFilterParams["$app_session_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$is_standard_event"] as! Bool)
    #expect(
      result.parameters.audienceFilterParams["$event_name"] as! String == "freeTrial_start")
    #expect(
      result.parameters.audienceFilterParams["$paywall_id"] as! String == paywallInfo.databaseId)
    #expect(
      result.parameters.audienceFilterParams["$paywalljs_version"] as? String ==
      paywallInfo.paywalljsVersion)
    #expect(
      result.parameters.audienceFilterParams["$paywall_identifier"] as! String ==
      paywallInfo.identifier)
    #expect(
      result.parameters.audienceFilterParams["$paywall_name"] as! String == paywallInfo.name)
    #expect(
      result.parameters.audienceFilterParams["$paywall_url"] as! String == paywallInfo.url.absoluteString)
    #expect(
      result.parameters.audienceFilterParams["$presented_by_event_name"] as? String == paywallInfo.presentedByPlacementWithName)
    #expect(
      result.parameters.audienceFilterParams["$presented_by_event_id"] as? String == paywallInfo.presentedByPlacementWithId)
    #expect(
      result.parameters.audienceFilterParams["$presented_by_event_timestamp"] as? String == paywallInfo.presentedByPlacementAt)
    #expect(
      result.parameters.audienceFilterParams["$presented_by"] as! String == paywallInfo.presentedBy)
    #expect(
      result.parameters.audienceFilterParams["$paywall_product_ids"] as? String == paywallInfo.productIds.joined(separator: ","))
    #expect(
      result.parameters.audienceFilterParams["$paywall_response_load_start_time"] as! String == paywallInfo.responseLoadStartTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_response_load_complete_time"] as! String == paywallInfo.responseLoadCompleteTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_response_load_duration"] as? TimeInterval == paywallInfo.responseLoadDuration)
    #expect(
      result.parameters.audienceFilterParams["$paywall_webview_load_start_time"] as! String == paywallInfo.webViewLoadStartTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_webview_load_complete_time"] as! String == paywallInfo.webViewLoadCompleteTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_webview_load_duration"] as? TimeInterval == paywallInfo.webViewLoadDuration)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_start_time"] as! String == paywallInfo.productsLoadStartTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_complete_time"] as! String == paywallInfo.productsLoadCompleteTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_fail_time"] as! String == paywallInfo.productsLoadFailTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_duration"] as? TimeInterval == paywallInfo.productsLoadDuration)
    #expect(
      result.parameters.audienceFilterParams["$is_free_trial_available"] as! Bool == paywallInfo.isFreeTrialAvailable)
    #expect(result.parameters.audienceFilterParams["$product_id"] as! String == productId)
    #expect(
      result.parameters.audienceFilterParams["$product_identifier"] as! String == productId)
    #expect(result.parameters.audienceFilterParams["$product_raw_price"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_price"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_period_alt"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_localized_period"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_period"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_periodly"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_weekly_price"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_daily_price"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_monthly_price"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_yearly_price"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_trial_period_days"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_trial_period_weeks"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_trial_period_months"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_trial_period_years"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_trial_period_text"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_trial_period_end_date"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_period_days"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_period_weeks"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_period_months"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_period_years"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_locale"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_language_code"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_currency_code"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_currency_symbol"] != nil)
    #expect(result.parameters.audienceFilterParams["$primary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$secondary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$tertiary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$app_session_id"] != nil)

    // Custom parameters
    #expect(
      result.parameters.audienceFilterParams["event_name"] as! String == "freeTrial_start")
    #expect(
      result.parameters.audienceFilterParams["paywall_id"] as! String == paywallInfo.databaseId)
    #expect(
      result.parameters.audienceFilterParams["paywall_name"] as! String == paywallInfo.name)
    #expect(
      result.parameters.audienceFilterParams["is_free_trial_available"] as! Bool == paywallInfo.isFreeTrialAvailable)
    #expect(
      result.parameters.audienceFilterParams["feature_gating"] as! String == FeatureGatingBehavior.nonGated.description)
    #expect(
      result.parameters.audienceFilterParams["presented_by"] as! String == paywallInfo.presentedBy)
    #expect(
      result.parameters.audienceFilterParams["paywall_product_ids"] as? String == paywallInfo.productIds.joined(separator: ","))
    #expect(result.parameters.audienceFilterParams["primary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["secondary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["tertiary_product_id"] != nil)
    #expect(
      result.parameters.audienceFilterParams["presented_by_event_name"] as? String == paywallInfo.presentedByPlacementWithName)
  }

  @Test func nonRecurringProductPurchase() async {
    let paywallInfo: PaywallInfo = .stub()
    let productId = "abc"
    let product = StoreProduct(
      sk1Product: MockSkProduct(productIdentifier: productId),
      entitlements: [.stub()]
    )
    let skTransaction = MockSKPaymentTransaction(state: .purchased)
    let dependencyContainer = DependencyContainer()
    let transaction = await dependencyContainer.makeStoreTransaction(from: skTransaction)
    let result = await Superwall.shared.track(
      InternalSuperwallEvent.NonRecurringProductPurchase(
        paywallInfo: paywallInfo, product: product, transaction: transaction))
    #expect(result.parameters.audienceFilterParams["$app_session_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$is_standard_event"] as! Bool)
    #expect(
      result.parameters.audienceFilterParams["$event_name"] as! String == "nonRecurringProduct_purchase")
    #expect(
      result.parameters.audienceFilterParams["$paywall_id"] as! String == paywallInfo.databaseId)
    #expect(
      result.parameters.audienceFilterParams["$paywalljs_version"] as? String ==
      paywallInfo.paywalljsVersion)
    #expect(
      result.parameters.audienceFilterParams["$paywall_identifier"] as! String ==
      paywallInfo.identifier)
    #expect(
      result.parameters.audienceFilterParams["$paywall_name"] as! String == paywallInfo.name)
    #expect(
      result.parameters.audienceFilterParams["$paywall_url"] as! String == paywallInfo.url.absoluteString)
    #expect(
      result.parameters.audienceFilterParams["$presented_by_event_name"] as? String == paywallInfo.presentedByPlacementWithName)
    #expect(
      result.parameters.audienceFilterParams["$presented_by_event_id"] as? String == paywallInfo.presentedByPlacementWithId)
    #expect(
      result.parameters.audienceFilterParams["$presented_by_event_timestamp"] as? String == paywallInfo.presentedByPlacementAt)
    #expect(
      result.parameters.audienceFilterParams["$presented_by"] as! String == paywallInfo.presentedBy)
    #expect(
      result.parameters.audienceFilterParams["$paywall_product_ids"] as? String == paywallInfo.productIds.joined(separator: ","))
    #expect(
      result.parameters.audienceFilterParams["$paywall_response_load_start_time"] as! String == paywallInfo.responseLoadStartTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_response_load_complete_time"] as! String == paywallInfo.responseLoadCompleteTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_response_load_duration"] as? TimeInterval == paywallInfo.responseLoadDuration)
    #expect(
      result.parameters.audienceFilterParams["$paywall_webview_load_start_time"] as! String == paywallInfo.webViewLoadStartTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_webview_load_complete_time"] as! String == paywallInfo.webViewLoadCompleteTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_webview_load_duration"] as? TimeInterval == paywallInfo.webViewLoadDuration)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_start_time"] as! String == paywallInfo.productsLoadStartTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_complete_time"] as! String == paywallInfo.productsLoadCompleteTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_fail_time"] as! String == paywallInfo.productsLoadFailTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_duration"] as? TimeInterval == paywallInfo.productsLoadDuration)
    #expect(
      result.parameters.audienceFilterParams["$is_free_trial_available"] as! Bool == paywallInfo.isFreeTrialAvailable)
    #expect(result.parameters.audienceFilterParams["$product_id"] as! String == productId)
    #expect(
      result.parameters.audienceFilterParams["$product_identifier"] as! String == productId)
    #expect(result.parameters.audienceFilterParams["$product_raw_price"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_price"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_period_alt"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_localized_period"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_period"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_periodly"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_weekly_price"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_daily_price"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_monthly_price"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_yearly_price"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_trial_period_days"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_trial_period_weeks"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_trial_period_months"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_trial_period_years"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_trial_period_text"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_trial_period_end_date"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_period_days"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_period_weeks"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_period_months"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_period_years"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_locale"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_language_code"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_currency_code"] != nil)
    #expect(result.parameters.audienceFilterParams["$product_currency_symbol"] != nil)
    #expect(result.parameters.audienceFilterParams["$primary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$secondary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$tertiary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$app_session_id"] != nil)

    // Custom parameters
    #expect(
      result.parameters.audienceFilterParams["event_name"] as! String == "nonRecurringProduct_purchase")
    #expect(
      result.parameters.audienceFilterParams["paywall_id"] as! String == paywallInfo.databaseId)
    #expect(
      result.parameters.audienceFilterParams["paywall_name"] as! String == paywallInfo.name)
    #expect(
      result.parameters.audienceFilterParams["is_free_trial_available"] as! Bool == paywallInfo.isFreeTrialAvailable)
    #expect(
      result.parameters.audienceFilterParams["feature_gating"] as! String == FeatureGatingBehavior.nonGated.description)
    #expect(
      result.parameters.audienceFilterParams["presented_by"] as! String == paywallInfo.presentedBy)
    #expect(
      result.parameters.audienceFilterParams["paywall_product_ids"] as? String == paywallInfo.productIds.joined(separator: ","))
    #expect(result.parameters.audienceFilterParams["primary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["secondary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["tertiary_product_id"] != nil)
    #expect(
      result.parameters.audienceFilterParams["presented_by_event_name"] as? String == paywallInfo.presentedByPlacementWithName)
  }

  @Test func paywallWebviewLoad_start() async {
    let paywallInfo: PaywallInfo = .stub()
    let result = await Superwall.shared.track(
      InternalSuperwallEvent.PaywallWebviewLoad(state: .start, paywallInfo: paywallInfo))
    #expect(result.parameters.audienceFilterParams["$app_session_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$is_standard_event"] as! Bool)
    #expect(
      result.parameters.audienceFilterParams["$event_name"] as! String == "paywallWebviewLoad_start")
    #expect(
      result.parameters.audienceFilterParams["$paywall_id"] as! String == paywallInfo.databaseId)
    #expect(
      result.parameters.audienceFilterParams["$paywalljs_version"] as? String ==
      paywallInfo.paywalljsVersion)
    #expect(
      result.parameters.audienceFilterParams["$paywall_identifier"] as! String ==
      paywallInfo.identifier)
    #expect(
      result.parameters.audienceFilterParams["$paywall_name"] as! String == paywallInfo.name)
    #expect(
      result.parameters.audienceFilterParams["$paywall_url"] as! String == paywallInfo.url.absoluteString)
    #expect(
      result.parameters.audienceFilterParams["$presented_by_event_name"] as? String == paywallInfo.presentedByPlacementWithName)
    #expect(
      result.parameters.audienceFilterParams["$presented_by_event_id"] as? String == paywallInfo.presentedByPlacementWithId)
    #expect(
      result.parameters.audienceFilterParams["$presented_by_event_timestamp"] as? String == paywallInfo.presentedByPlacementAt)
    #expect(
      result.parameters.audienceFilterParams["$presented_by"] as! String == paywallInfo.presentedBy)
    #expect(
      result.parameters.audienceFilterParams["$paywall_product_ids"] as? String == paywallInfo.productIds.joined(separator: ","))
    #expect(
      result.parameters.audienceFilterParams["$paywall_response_load_start_time"] as! String == paywallInfo.responseLoadStartTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_response_load_complete_time"] as! String == paywallInfo.responseLoadCompleteTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_response_load_duration"] as? TimeInterval == paywallInfo.responseLoadDuration)
    #expect(
      result.parameters.audienceFilterParams["$paywall_webview_load_start_time"] as! String == paywallInfo.webViewLoadStartTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_webview_load_complete_time"] as! String == paywallInfo.webViewLoadCompleteTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_webview_load_duration"] as? TimeInterval == paywallInfo.webViewLoadDuration)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_start_time"] as! String == paywallInfo.productsLoadStartTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_complete_time"] as! String == paywallInfo.productsLoadCompleteTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_fail_time"] as! String == paywallInfo.productsLoadFailTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_duration"] as? TimeInterval == paywallInfo.productsLoadDuration)
    #expect(
      result.parameters.audienceFilterParams["$is_free_trial_available"] as! Bool == paywallInfo.isFreeTrialAvailable)
    #expect(result.parameters.audienceFilterParams["$primary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$secondary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$tertiary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$app_session_id"] != nil)

    // Custom parameters
    #expect(
      result.parameters.audienceFilterParams["event_name"] as! String == "paywallWebviewLoad_start")
    #expect(
      result.parameters.audienceFilterParams["paywall_id"] as! String == paywallInfo.databaseId)
    #expect(
      result.parameters.audienceFilterParams["paywall_name"] as! String == paywallInfo.name)
    #expect(
      result.parameters.audienceFilterParams["is_free_trial_available"] as! Bool == paywallInfo.isFreeTrialAvailable)
    #expect(
      result.parameters.audienceFilterParams["feature_gating"] as! String == FeatureGatingBehavior.nonGated.description)
    #expect(
      result.parameters.audienceFilterParams["presented_by"] as! String == paywallInfo.presentedBy)
    #expect(
      result.parameters.audienceFilterParams["paywall_product_ids"] as? String == paywallInfo.productIds.joined(separator: ","))
    #expect(result.parameters.audienceFilterParams["primary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["secondary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["tertiary_product_id"] != nil)
    #expect(
      result.parameters.audienceFilterParams["presented_by_event_name"] as? String == paywallInfo.presentedByPlacementWithName)
  }

  @Test func paywallWebviewLoad_fail() async {
    let paywallInfo: PaywallInfo = .stub()
    let result = await Superwall.shared.track(
      InternalSuperwallEvent.PaywallWebviewLoad(
        state: .fail(NetworkError.unknown, []), paywallInfo: paywallInfo))
    #expect(result.parameters.audienceFilterParams["$app_session_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$is_standard_event"] as! Bool)
    #expect(
      result.parameters.audienceFilterParams["$event_name"] as! String == "paywallWebviewLoad_fail")
    #expect(
      result.parameters.audienceFilterParams["$paywall_id"] as! String == paywallInfo.databaseId)
    #expect(
      result.parameters.audienceFilterParams["$paywalljs_version"] as? String ==
      paywallInfo.paywalljsVersion)
    #expect(
      result.parameters.audienceFilterParams["$paywall_identifier"] as! String ==
      paywallInfo.identifier)
    #expect(
      result.parameters.audienceFilterParams["$paywall_name"] as! String == paywallInfo.name)
    #expect(
      result.parameters.audienceFilterParams["$paywall_url"] as! String == paywallInfo.url.absoluteString)
    #expect(
      result.parameters.audienceFilterParams["$presented_by_event_name"] as? String == paywallInfo.presentedByPlacementWithName)
    #expect(
      result.parameters.audienceFilterParams["$presented_by_event_id"] as? String == paywallInfo.presentedByPlacementWithId)
    #expect(
      result.parameters.audienceFilterParams["$presented_by_event_timestamp"] as? String == paywallInfo.presentedByPlacementAt)
    #expect(
      result.parameters.audienceFilterParams["$presented_by"] as! String == paywallInfo.presentedBy)
    #expect(
      result.parameters.audienceFilterParams["$paywall_product_ids"] as? String == paywallInfo.productIds.joined(separator: ","))
    #expect(
      result.parameters.audienceFilterParams["$paywall_response_load_start_time"] as! String == paywallInfo.responseLoadStartTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_response_load_complete_time"] as! String == paywallInfo.responseLoadCompleteTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_response_load_duration"] as? TimeInterval == paywallInfo.responseLoadDuration)
    #expect(
      result.parameters.audienceFilterParams["$paywall_webview_load_start_time"] as! String == paywallInfo.webViewLoadStartTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_webview_load_complete_time"] as! String == paywallInfo.webViewLoadCompleteTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_webview_load_duration"] as? TimeInterval == paywallInfo.webViewLoadDuration)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_start_time"] as! String == paywallInfo.productsLoadStartTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_complete_time"] as! String == paywallInfo.productsLoadCompleteTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_fail_time"] as! String == paywallInfo.productsLoadFailTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_duration"] as? TimeInterval == paywallInfo.productsLoadDuration)
    #expect(
      result.parameters.audienceFilterParams["$is_free_trial_available"] as! Bool == paywallInfo.isFreeTrialAvailable)
    #expect(result.parameters.audienceFilterParams["$primary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$secondary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$tertiary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$app_session_id"] != nil)

    // Custom parameters
    #expect(
      result.parameters.audienceFilterParams["event_name"] as! String == "paywallWebviewLoad_fail")
    #expect(
      result.parameters.audienceFilterParams["paywall_id"] as! String == paywallInfo.databaseId)
    #expect(
      result.parameters.audienceFilterParams["paywall_name"] as! String == paywallInfo.name)
    #expect(
      result.parameters.audienceFilterParams["is_free_trial_available"] as! Bool == paywallInfo.isFreeTrialAvailable)
    #expect(
      result.parameters.audienceFilterParams["feature_gating"] as! String == FeatureGatingBehavior.nonGated.description)
    #expect(
      result.parameters.audienceFilterParams["presented_by"] as! String == paywallInfo.presentedBy)
    #expect(
      result.parameters.audienceFilterParams["paywall_product_ids"] as? String == paywallInfo.productIds.joined(separator: ","))
    #expect(result.parameters.audienceFilterParams["primary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["secondary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["tertiary_product_id"] != nil)
    #expect(
      result.parameters.audienceFilterParams["presented_by_event_name"] as? String == paywallInfo.presentedByPlacementWithName)
  }

  @Test func paywallWebviewLoad_complete() async {
    let paywallInfo: PaywallInfo = .stub()
    let result = await Superwall.shared.track(
      InternalSuperwallEvent.PaywallWebviewLoad(state: .complete, paywallInfo: paywallInfo))
    #expect(result.parameters.audienceFilterParams["$app_session_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$is_standard_event"] as! Bool)
    #expect(
      result.parameters.audienceFilterParams["$event_name"] as! String == "paywallWebviewLoad_complete")
    #expect(
      result.parameters.audienceFilterParams["$paywall_id"] as! String == paywallInfo.databaseId)
    #expect(
      result.parameters.audienceFilterParams["$paywalljs_version"] as? String ==
      paywallInfo.paywalljsVersion)
    #expect(
      result.parameters.audienceFilterParams["$paywall_identifier"] as! String ==
      paywallInfo.identifier)
    #expect(
      result.parameters.audienceFilterParams["$paywall_name"] as! String == paywallInfo.name)
    #expect(
      result.parameters.audienceFilterParams["$paywall_url"] as! String == paywallInfo.url.absoluteString)
    #expect(
      result.parameters.audienceFilterParams["$presented_by_event_name"] as? String == paywallInfo.presentedByPlacementWithName)
    #expect(
      result.parameters.audienceFilterParams["$presented_by_event_id"] as? String == paywallInfo.presentedByPlacementWithId)
    #expect(
      result.parameters.audienceFilterParams["$presented_by_event_timestamp"] as? String == paywallInfo.presentedByPlacementAt)
    #expect(
      result.parameters.audienceFilterParams["$presented_by"] as! String == paywallInfo.presentedBy)
    #expect(
      result.parameters.audienceFilterParams["$paywall_product_ids"] as? String == paywallInfo.productIds.joined(separator: ","))
    #expect(
      result.parameters.audienceFilterParams["$paywall_response_load_start_time"] as! String == paywallInfo.responseLoadStartTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_response_load_complete_time"] as! String == paywallInfo.responseLoadCompleteTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_response_load_duration"] as? TimeInterval == paywallInfo.responseLoadDuration)
    #expect(
      result.parameters.audienceFilterParams["$paywall_webview_load_start_time"] as! String == paywallInfo.webViewLoadStartTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_webview_load_complete_time"] as! String == paywallInfo.webViewLoadCompleteTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_webview_load_duration"] as? TimeInterval == paywallInfo.webViewLoadDuration)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_start_time"] as! String == paywallInfo.productsLoadStartTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_complete_time"] as! String == paywallInfo.productsLoadCompleteTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_fail_time"] as! String == paywallInfo.productsLoadFailTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_duration"] as? TimeInterval == paywallInfo.productsLoadDuration)
    #expect(
      result.parameters.audienceFilterParams["$is_free_trial_available"] as! Bool == paywallInfo.isFreeTrialAvailable)
    #expect(result.parameters.audienceFilterParams["$primary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$secondary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$tertiary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$app_session_id"] != nil)

    // Custom parameters
    #expect(
      result.parameters.audienceFilterParams["event_name"] as! String == "paywallWebviewLoad_complete"
    )
    #expect(
      result.parameters.audienceFilterParams["paywall_id"] as! String == paywallInfo.databaseId)
    #expect(
      result.parameters.audienceFilterParams["paywall_name"] as! String == paywallInfo.name)
    #expect(
      result.parameters.audienceFilterParams["is_free_trial_available"] as! Bool == paywallInfo.isFreeTrialAvailable)
    #expect(
      result.parameters.audienceFilterParams["feature_gating"] as! String == FeatureGatingBehavior.nonGated.description)
    #expect(
      result.parameters.audienceFilterParams["presented_by"] as! String == paywallInfo.presentedBy)
    #expect(
      result.parameters.audienceFilterParams["paywall_product_ids"] as? String == paywallInfo.productIds.joined(separator: ","))
    #expect(result.parameters.audienceFilterParams["primary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["secondary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["tertiary_product_id"] != nil)
    #expect(
      result.parameters.audienceFilterParams["presented_by_event_name"] as? String == paywallInfo.presentedByPlacementWithName)
  }

  @Test func paywallWebviewLoad_timeout() async {
    let paywallInfo: PaywallInfo = .stub()
    let result = await Superwall.shared.track(
      InternalSuperwallEvent.PaywallWebviewLoad(state: .timeout, paywallInfo: paywallInfo))
    #expect(result.parameters.audienceFilterParams["$app_session_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$is_standard_event"] as! Bool)
    #expect(
      result.parameters.audienceFilterParams["$event_name"] as! String == "paywallWebviewLoad_timeout"
    )
    #expect(
      result.parameters.audienceFilterParams["$paywall_id"] as! String == paywallInfo.databaseId)
    #expect(
      result.parameters.audienceFilterParams["$paywalljs_version"] as? String ==
      paywallInfo.paywalljsVersion)
    #expect(
      result.parameters.audienceFilterParams["$paywall_identifier"] as! String ==
      paywallInfo.identifier)
    #expect(
      result.parameters.audienceFilterParams["$paywall_name"] as! String == paywallInfo.name)
    #expect(
      result.parameters.audienceFilterParams["$paywall_url"] as! String == paywallInfo.url.absoluteString)
    #expect(
      result.parameters.audienceFilterParams["$presented_by_event_name"] as? String == paywallInfo.presentedByPlacementWithName)
    #expect(
      result.parameters.audienceFilterParams["$presented_by_event_id"] as? String == paywallInfo.presentedByPlacementWithId)
    #expect(
      result.parameters.audienceFilterParams["$presented_by_event_timestamp"] as? String == paywallInfo.presentedByPlacementAt)
    #expect(
      result.parameters.audienceFilterParams["$presented_by"] as! String == paywallInfo.presentedBy)
    #expect(
      result.parameters.audienceFilterParams["$paywall_product_ids"] as? String == paywallInfo.productIds.joined(separator: ","))
    #expect(
      result.parameters.audienceFilterParams["$paywall_response_load_start_time"] as! String == paywallInfo.responseLoadStartTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_response_load_complete_time"] as! String == paywallInfo.responseLoadCompleteTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_response_load_duration"] as? TimeInterval == paywallInfo.responseLoadDuration)
    #expect(
      result.parameters.audienceFilterParams["$paywall_webview_load_start_time"] as! String == paywallInfo.webViewLoadStartTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_webview_load_complete_time"] as! String == paywallInfo.webViewLoadCompleteTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_webview_load_duration"] as? TimeInterval == paywallInfo.webViewLoadDuration)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_start_time"] as! String == paywallInfo.productsLoadStartTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_complete_time"] as! String == paywallInfo.productsLoadCompleteTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_fail_time"] as! String == paywallInfo.productsLoadFailTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_duration"] as? TimeInterval == paywallInfo.productsLoadDuration)
    #expect(
      result.parameters.audienceFilterParams["$is_free_trial_available"] as! Bool == paywallInfo.isFreeTrialAvailable)
    #expect(result.parameters.audienceFilterParams["$primary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$secondary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$tertiary_product_id"] != nil)

    // Custom parameters
    #expect(
      result.parameters.audienceFilterParams["event_name"] as! String == "paywallWebviewLoad_timeout")
    #expect(
      result.parameters.audienceFilterParams["paywall_id"] as! String == paywallInfo.databaseId)
    #expect(
      result.parameters.audienceFilterParams["paywall_name"] as! String == paywallInfo.name)
    #expect(
      result.parameters.audienceFilterParams["is_free_trial_available"] as! Bool == paywallInfo.isFreeTrialAvailable)
    #expect(
      result.parameters.audienceFilterParams["feature_gating"] as! String == FeatureGatingBehavior.nonGated.description)
    #expect(
      result.parameters.audienceFilterParams["presented_by"] as! String == paywallInfo.presentedBy)
    #expect(
      result.parameters.audienceFilterParams["paywall_product_ids"] as? String == paywallInfo.productIds.joined(separator: ","))
    #expect(result.parameters.audienceFilterParams["primary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["secondary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["tertiary_product_id"] != nil)
    #expect(
      result.parameters.audienceFilterParams["presented_by_event_name"] as? String == paywallInfo.presentedByPlacementWithName)
  }

  @Test func paywallProductsLoad_start() async {
    let paywallInfo: PaywallInfo = .stub()
    let placementData: PlacementData = .stub()
    let result = await Superwall.shared.track(
      InternalSuperwallEvent.PaywallProductsLoad(
        state: .start, paywallInfo: paywallInfo, placementData: placementData))
    #expect(result.parameters.audienceFilterParams["$app_session_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$is_standard_event"] as! Bool)
    #expect(
      result.parameters.audienceFilterParams["$event_name"] as! String == "paywallProductsLoad_start")
    #expect(result.parameters.audienceFilterParams["$is_triggered_from_event"] as! Bool)
    #expect(
      result.parameters.audienceFilterParams["$paywall_id"] as! String == paywallInfo.databaseId)
    #expect(
      result.parameters.audienceFilterParams["$paywalljs_version"] as? String ==
      paywallInfo.paywalljsVersion)
    #expect(
      result.parameters.audienceFilterParams["$paywall_identifier"] as! String ==
      paywallInfo.identifier)
    #expect(
      result.parameters.audienceFilterParams["$paywall_name"] as! String == paywallInfo.name)
    #expect(
      result.parameters.audienceFilterParams["$paywall_url"] as! String == paywallInfo.url.absoluteString)
    #expect(
      result.parameters.audienceFilterParams["$presented_by_event_name"] as? String == paywallInfo.presentedByPlacementWithName)
    #expect(
      result.parameters.audienceFilterParams["$presented_by_event_id"] as? String == paywallInfo.presentedByPlacementWithId)
    #expect(
      result.parameters.audienceFilterParams["$presented_by_event_timestamp"] as? String == paywallInfo.presentedByPlacementAt)
    #expect(
      result.parameters.audienceFilterParams["$presented_by"] as! String == paywallInfo.presentedBy)
    #expect(
      result.parameters.audienceFilterParams["$paywall_product_ids"] as? String == paywallInfo.productIds.joined(separator: ","))
    #expect(
      result.parameters.audienceFilterParams["$paywall_response_load_start_time"] as! String == paywallInfo.responseLoadStartTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_response_load_complete_time"] as! String == paywallInfo.responseLoadCompleteTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_response_load_duration"] as? TimeInterval == paywallInfo.responseLoadDuration)
    #expect(
      result.parameters.audienceFilterParams["$paywall_webview_load_start_time"] as! String == paywallInfo.webViewLoadStartTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_webview_load_complete_time"] as! String == paywallInfo.webViewLoadCompleteTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_webview_load_duration"] as? TimeInterval == paywallInfo.webViewLoadDuration)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_start_time"] as! String == paywallInfo.productsLoadStartTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_complete_time"] as! String == paywallInfo.productsLoadCompleteTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_fail_time"] as! String == paywallInfo.productsLoadFailTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_duration"] as? TimeInterval == paywallInfo.productsLoadDuration)
    #expect(
      result.parameters.audienceFilterParams["$is_free_trial_available"] as! Bool == paywallInfo.isFreeTrialAvailable)
    #expect(result.parameters.audienceFilterParams["$primary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$secondary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$tertiary_product_id"] != nil)

    // Custom parameters
    #expect(
      result.parameters.audienceFilterParams["event_name"] as! String == "paywallProductsLoad_start")
    #expect(
      result.parameters.audienceFilterParams["paywall_id"] as! String == paywallInfo.databaseId)
    #expect(
      result.parameters.audienceFilterParams["paywall_name"] as! String == paywallInfo.name)
    #expect(
      result.parameters.audienceFilterParams["is_free_trial_available"] as! Bool == paywallInfo.isFreeTrialAvailable)
    #expect(
      result.parameters.audienceFilterParams["feature_gating"] as! String == FeatureGatingBehavior.nonGated.description)
    #expect(
      result.parameters.audienceFilterParams["presented_by"] as! String == paywallInfo.presentedBy)
    #expect(
      result.parameters.audienceFilterParams["paywall_product_ids"] as? String == paywallInfo.productIds.joined(separator: ","))
    #expect(result.parameters.audienceFilterParams["primary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["secondary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["tertiary_product_id"] != nil)
    #expect(
      result.parameters.audienceFilterParams["presented_by_event_name"] as? String == paywallInfo.presentedByPlacementWithName)
  }

  @Test func paywallProductsLoad_fail() async {
    let paywallInfo: PaywallInfo = .stub()
    let placementData: PlacementData = .stub()
    let result = await Superwall.shared.track(
      InternalSuperwallEvent.PaywallProductsLoad(
        state: .fail(NetworkError.unknown), paywallInfo: paywallInfo, placementData: placementData))
    #expect(result.parameters.audienceFilterParams["$app_session_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$is_standard_event"] as! Bool)
    #expect(
      result.parameters.audienceFilterParams["$event_name"] as! String == "paywallProductsLoad_fail")
    #expect(result.parameters.audienceFilterParams["$is_triggered_from_event"] as! Bool)
    #expect(
      result.parameters.audienceFilterParams["$paywall_id"] as! String == paywallInfo.databaseId)
    #expect(
      result.parameters.audienceFilterParams["$paywalljs_version"] as? String ==
      paywallInfo.paywalljsVersion)
    #expect(
      result.parameters.audienceFilterParams["$paywall_identifier"] as! String ==
      paywallInfo.identifier)
    #expect(
      result.parameters.audienceFilterParams["$paywall_name"] as! String == paywallInfo.name)
    #expect(
      result.parameters.audienceFilterParams["$paywall_url"] as! String == paywallInfo.url.absoluteString)
    #expect(
      result.parameters.audienceFilterParams["$presented_by_event_name"] as? String == paywallInfo.presentedByPlacementWithName)
    #expect(
      result.parameters.audienceFilterParams["$presented_by_event_id"] as? String == paywallInfo.presentedByPlacementWithId)
    #expect(
      result.parameters.audienceFilterParams["$presented_by_event_timestamp"] as? String == paywallInfo.presentedByPlacementAt)
    #expect(
      result.parameters.audienceFilterParams["$presented_by"] as! String == paywallInfo.presentedBy)
    #expect(
      result.parameters.audienceFilterParams["$paywall_product_ids"] as? String == paywallInfo.productIds.joined(separator: ","))
    #expect(
      result.parameters.audienceFilterParams["$paywall_response_load_start_time"] as! String == paywallInfo.responseLoadStartTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_response_load_complete_time"] as! String == paywallInfo.responseLoadCompleteTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_response_load_duration"] as? TimeInterval == paywallInfo.responseLoadDuration)
    #expect(
      result.parameters.audienceFilterParams["$paywall_webview_load_start_time"] as! String == paywallInfo.webViewLoadStartTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_webview_load_complete_time"] as! String == paywallInfo.webViewLoadCompleteTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_webview_load_duration"] as? TimeInterval == paywallInfo.webViewLoadDuration)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_start_time"] as! String == paywallInfo.productsLoadStartTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_complete_time"] as! String == paywallInfo.productsLoadCompleteTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_fail_time"] as! String == paywallInfo.productsLoadFailTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_duration"] as? TimeInterval == paywallInfo.productsLoadDuration)
    #expect(
      result.parameters.audienceFilterParams["$is_free_trial_available"] as! Bool == paywallInfo.isFreeTrialAvailable)
    #expect(result.parameters.audienceFilterParams["$primary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$secondary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$tertiary_product_id"] != nil)

    // Custom parameters
    #expect(
      result.parameters.audienceFilterParams["event_name"] as! String == "paywallProductsLoad_fail")
    #expect(
      result.parameters.audienceFilterParams["paywall_id"] as! String == paywallInfo.databaseId)
    #expect(
      result.parameters.audienceFilterParams["paywall_name"] as! String == paywallInfo.name)
    #expect(
      result.parameters.audienceFilterParams["is_free_trial_available"] as! Bool == paywallInfo.isFreeTrialAvailable)
    #expect(
      result.parameters.audienceFilterParams["feature_gating"] as! String == FeatureGatingBehavior.nonGated.description)
    #expect(
      result.parameters.audienceFilterParams["presented_by"] as! String == paywallInfo.presentedBy)
    #expect(
      result.parameters.audienceFilterParams["paywall_product_ids"] as? String == paywallInfo.productIds.joined(separator: ","))
    #expect(result.parameters.audienceFilterParams["primary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["secondary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["tertiary_product_id"] != nil)
    #expect(
      result.parameters.audienceFilterParams["presented_by_event_name"] as? String == paywallInfo.presentedByPlacementWithName)
  }

  @Test func paywallProductsLoad_complete() async {
    let paywallInfo: PaywallInfo = .stub()
    let placementData: PlacementData = .stub()
    let result = await Superwall.shared.track(
      InternalSuperwallEvent.PaywallProductsLoad(
        state: .complete, paywallInfo: paywallInfo, placementData: placementData))
    #expect(result.parameters.audienceFilterParams["$app_session_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$is_standard_event"] as! Bool)
    #expect(
      result.parameters.audienceFilterParams["$event_name"] as! String == "paywallProductsLoad_complete")
    #expect(result.parameters.audienceFilterParams["$is_triggered_from_event"] as! Bool)
    #expect(
      result.parameters.audienceFilterParams["$paywall_id"] as! String == paywallInfo.databaseId)
    #expect(
      result.parameters.audienceFilterParams["$paywalljs_version"] as? String ==
      paywallInfo.paywalljsVersion)
    #expect(
      result.parameters.audienceFilterParams["$paywall_identifier"] as! String ==
      paywallInfo.identifier)
    #expect(
      result.parameters.audienceFilterParams["$paywall_name"] as! String == paywallInfo.name)
    #expect(
      result.parameters.audienceFilterParams["$paywall_url"] as! String == paywallInfo.url.absoluteString)
    #expect(
      result.parameters.audienceFilterParams["$presented_by_event_name"] as? String == paywallInfo.presentedByPlacementWithName)
    #expect(
      result.parameters.audienceFilterParams["$presented_by_event_id"] as? String == paywallInfo.presentedByPlacementWithId)
    #expect(
      result.parameters.audienceFilterParams["$presented_by_event_timestamp"] as? String == paywallInfo.presentedByPlacementAt)
    #expect(
      result.parameters.audienceFilterParams["$presented_by"] as! String == paywallInfo.presentedBy)
    #expect(
      result.parameters.audienceFilterParams["$paywall_product_ids"] as? String == paywallInfo.productIds.joined(separator: ","))
    #expect(
      result.parameters.audienceFilterParams["$paywall_response_load_start_time"] as! String == paywallInfo.responseLoadStartTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_response_load_complete_time"] as! String == paywallInfo.responseLoadCompleteTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_response_load_duration"] as? TimeInterval == paywallInfo.responseLoadDuration)
    #expect(
      result.parameters.audienceFilterParams["$paywall_webview_load_start_time"] as! String == paywallInfo.webViewLoadStartTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_webview_load_complete_time"] as! String == paywallInfo.webViewLoadCompleteTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_webview_load_duration"] as? TimeInterval == paywallInfo.webViewLoadDuration)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_start_time"] as! String == paywallInfo.productsLoadStartTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_complete_time"] as! String == paywallInfo.productsLoadCompleteTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_fail_time"] as! String == paywallInfo.productsLoadFailTime!)
    #expect(
      result.parameters.audienceFilterParams["$paywall_products_load_duration"] as? TimeInterval == paywallInfo.productsLoadDuration)
    #expect(
      result.parameters.audienceFilterParams["$is_free_trial_available"] as! Bool == paywallInfo.isFreeTrialAvailable)
    #expect(result.parameters.audienceFilterParams["$primary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$secondary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$tertiary_product_id"] != nil)

    // Custom parameters
    #expect(
      result.parameters.audienceFilterParams["event_name"] as! String == "paywallProductsLoad_complete")
    #expect(
      result.parameters.audienceFilterParams["paywall_id"] as! String == paywallInfo.databaseId)
    #expect(
      result.parameters.audienceFilterParams["paywall_name"] as! String == paywallInfo.name)
    #expect(
      result.parameters.audienceFilterParams["is_free_trial_available"] as! Bool == paywallInfo.isFreeTrialAvailable)
    #expect(
      result.parameters.audienceFilterParams["feature_gating"] as! String == FeatureGatingBehavior.nonGated.description)
    #expect(
      result.parameters.audienceFilterParams["presented_by"] as! String == paywallInfo.presentedBy)
    #expect(
      result.parameters.audienceFilterParams["paywall_product_ids"] as? String == paywallInfo.productIds.joined(separator: ","))
    #expect(result.parameters.audienceFilterParams["primary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["secondary_product_id"] != nil)
    #expect(result.parameters.audienceFilterParams["tertiary_product_id"] != nil)
    #expect(
      result.parameters.audienceFilterParams["presented_by_event_name"] as? String == paywallInfo.presentedByPlacementWithName)
  }

  @Test func paywallPreloadStart() async {
    let paywallCount = 5
    let result = await Superwall.shared.track(
      InternalSuperwallEvent.PaywallPreload(state: .start, paywallCount: paywallCount))
    #expect(result.parameters.audienceFilterParams["$app_session_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$is_standard_event"] as! Bool)
    #expect(
      result.parameters.audienceFilterParams["$event_name"] as! String == "paywallPreload_start")
    #expect(
      result.parameters.audienceFilterParams["$paywall_count"] as! Int == paywallCount)
  }

  @Test func paywallPreloadComplete() async {
    let paywallCount = 3
    let result = await Superwall.shared.track(
      InternalSuperwallEvent.PaywallPreload(state: .complete, paywallCount: paywallCount))
    #expect(result.parameters.audienceFilterParams["$app_session_id"] != nil)
    #expect(result.parameters.audienceFilterParams["$is_standard_event"] as! Bool)
    #expect(
      result.parameters.audienceFilterParams["$event_name"] as! String == "paywallPreload_complete")
    #expect(
      result.parameters.audienceFilterParams["$paywall_count"] as! Int == paywallCount)
  }
}
