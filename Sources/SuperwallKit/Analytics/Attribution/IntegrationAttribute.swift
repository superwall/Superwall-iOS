//
//  IntegrationAttribute.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 13/08/2025.
//

/// An enum that represents attributes for third-party integrations with Superwall.
@objc(SWKIntegrationAttribute)
public enum IntegrationAttribute: Int {
  /// The unique Adjust identifier for the user.
  case adjustId

  /// The Amplitude device identifier.
  case amplitudeDeviceId

  /// The Amplitude user identifier.
  case amplitudeUserId

  /// The unique Appsflyer identifier for the user.
  case appsflyerId

  /// The Braze `alias_name` in User Alias Object.
  case brazeAliasName

  /// The Braze `alias_label` in User Alias Object.
  case brazeAliasLabel

  /// The OneSignal Player identifier for the user.
  case onesignalId

  /// The Facebook Anonymous identifier for the user.
  case fbAnonId

  /// The Firebase instance identifier.
  case firebaseAppInstanceId

  /// The Iterable identifier for the user.
  case iterableUserId

  /// The Iterable campaign identifier.
  case iterableCampaignId

  /// The Iterable template identifier.
  case iterableTemplateId

  /// The Mixpanel user identifier.
  case mixpanelDistinctId

  /// The unique mParticle user identifier (mpid).
  case mparticleId

  /// The CleverTap user identifier.
  case clevertapId

  /// The Airship channel identifier for the user.
  case airshipChannelId

  /// The unique Kochava device identifier.
  case kochavaDeviceId

  /// The Tenjin identifier.
  case tenjinId

  /// The PostHog User identifer
  case posthogUserId

  /// The Customer.io person's identifier (`id)`.
  case customerioId
}

// MARK: - CustomStringConvertible
extension IntegrationAttribute: CustomStringConvertible {
  public var description: String {
    switch self {
    case .adjustId:
      return "adjustId"
    case .amplitudeDeviceId:
      return "amplitudeDeviceId"
    case .amplitudeUserId:
      return "amplitudeUserId"
    case .appsflyerId:
      return "appsflyerId"
    case .brazeAliasName:
      return "brazeAliasName"
    case .brazeAliasLabel:
      return "brazeAliasLabel"
    case .onesignalId:
      return "onesignalId"
    case .fbAnonId:
      return "fbAnonId"
    case .firebaseAppInstanceId:
      return "firebaseAppInstanceId"
    case .iterableUserId:
      return "iterableUserId"
    case .iterableCampaignId:
      return "iterableCampaignId"
    case .iterableTemplateId:
      return "iterableTemplateId"
    case .mixpanelDistinctId:
      return "mixpanelDistinctId"
    case .mparticleId:
      return "mparticleId"
    case .clevertapId:
      return "clevertapId"
    case .airshipChannelId:
      return "airshipChannelId"
    case .kochavaDeviceId:
      return "kochavaDeviceId"
    case .tenjinId:
      return "tenjinId"
    case .posthogUserId:
      return "posthogUserId"
    case .customerioId:
      return "customerioId"
    }
  }
}
