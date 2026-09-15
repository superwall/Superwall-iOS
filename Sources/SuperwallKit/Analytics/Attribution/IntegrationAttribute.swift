//
//  IntegrationAttribute.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 13/08/2025.
//

/// An enum that represents attributes for third-party integrations with Superwall.
@objc(SWKIntegrationAttribute)
public enum IntegrationAttribute: Int {
  /// The unique Adjust identifier for the device.
  ///
  /// Kept when you reset or identify a different user.
  case adjustId

  /// The Amplitude device identifier.
  ///
  /// Kept when you reset or identify a different user.
  case amplitudeDeviceId

  /// The Amplitude user identifier.
  ///
  /// Cleared when you reset or identify a different user.
  case amplitudeUserId

  /// The unique Appsflyer identifier for the device.
  ///
  /// Kept when you reset or identify a different user.
  case appsflyerId

  /// The Braze `alias_name` in User Alias Object.
  ///
  /// Cleared when you reset or identify a different user.
  case brazeAliasName

  /// The Braze `alias_label` in User Alias Object.
  ///
  /// Cleared when you reset or identify a different user.
  case brazeAliasLabel

  /// The OneSignal User ID (`onesignal_id`) for the user.
  ///
  /// Cleared when you reset or identify a different user.
  case onesignalId

  /// The Facebook Anonymous identifier for the app install.
  ///
  /// Kept when you reset or identify a different user.
  case fbAnonId

  /// The Firebase instance identifier.
  ///
  /// Kept when you reset or identify a different user.
  case firebaseAppInstanceId

  /// The Firebase installation ID.
  ///
  /// Kept when you reset or identify a different user.
  case firebaseInstallationId

  /// The Iterable identifier for the user.
  ///
  /// Cleared when you reset or identify a different user.
  case iterableUserId

  /// The Iterable campaign identifier.
  ///
  /// Cleared when you reset or identify a different user.
  case iterableCampaignId

  /// The Iterable template identifier.
  ///
  /// Cleared when you reset or identify a different user.
  case iterableTemplateId

  /// The Mixpanel user identifier.
  ///
  /// Cleared when you reset or identify a different user.
  case mixpanelDistinctId

  /// The unique mParticle user identifier (mpid).
  ///
  /// Cleared when you reset or identify a different user.
  case mparticleId

  /// The CleverTap user identifier.
  ///
  /// Cleared when you reset or identify a different user.
  case clevertapId

  /// The Airship channel identifier, which registers the device rather than
  /// the named user.
  ///
  /// Kept when you reset or identify a different user.
  case airshipChannelId

  /// The unique Kochava device identifier.
  ///
  /// Kept when you reset or identify a different user.
  case kochavaDeviceId

  /// The Tenjin device identifier.
  ///
  /// Kept when you reset or identify a different user.
  case tenjinId

  /// The PostHog User identifer
  ///
  /// Cleared when you reset or identify a different user.
  case posthogUserId

  /// The Customer.io person's identifier (`id)`.
  ///
  /// Cleared when you reset or identify a different user.
  case customerioId

  /// The Appstack device identifier.
  ///
  /// Kept when you reset or identify a different user.
  case appstackId

  /// The Singular device identifier (SDID).
  ///
  /// Kept when you reset or identify a different user.
  case singularDeviceId
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
    case .firebaseInstallationId:
      return "firebaseInstallationId"
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
    case .appstackId:
      return "appstackId"
    case .singularDeviceId:
      return "singularDeviceId"
    }
  }
}

// MARK: - Scope
extension IntegrationAttribute {
  /// Whether the identifier belongs to the app install rather than to the
  /// person using it.
  ///
  /// A reset or an `identify` to a different user keeps the install-scoped
  /// identifiers — they describe the same device either way — and drops the
  /// rest, which belong to whoever was just signed out. The switch is
  /// exhaustive on purpose: a new integration has to be placed on one side.
  var isInstallScoped: Bool {
    switch self {
    case .adjustId,
      .amplitudeDeviceId,
      .appsflyerId,
      .fbAnonId,
      .firebaseAppInstanceId,
      .firebaseInstallationId,
      .airshipChannelId,
      .kochavaDeviceId,
      .tenjinId,
      .appstackId,
      .singularDeviceId:
      return true
    case .amplitudeUserId,
      .brazeAliasName,
      .brazeAliasLabel,
      .onesignalId,
      .iterableUserId,
      .iterableCampaignId,
      .iterableTemplateId,
      .mixpanelDistinctId,
      .mparticleId,
      .clevertapId,
      .posthogUserId,
      .customerioId:
      return false
    }
  }

  /// Every case, in declaration order.
  ///
  /// Walks the raw values rather than listing the cases, so a new integration
  /// is picked up on its own and can't be left out of the scope split by
  /// accident.
  static let allAttributes: [IntegrationAttribute] = {
    var attributes: [IntegrationAttribute] = []
    var rawValue = 0
    while let attribute = IntegrationAttribute(rawValue: rawValue) {
      attributes.append(attribute)
      rawValue += 1
    }
    return attributes
  }()

  /// The keys of every identifier that survives a reset.
  static let installScopedKeys: Set<String> = Set(
    allAttributes.filter(\.isInstallScoped).map(\.description)
  )
}
