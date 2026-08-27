//
//  CustomerCenterConfiguration.swift
//
//
//  Created by Jordan Morgan on 20/08/2026.
//

import Foundation
import UIKit

/// Configures the screens, actions, support options and appearance of the Customer Center.
///
/// Set the default via ``SuperwallOptions/customerCenter`` before calling `configure`, or pass one to
/// ``Superwall/presentCustomerCenter(configuration:from:delegate:onDismiss:)``.
@objc(SWKCustomerCenterConfiguration)
@objcMembers
public final class CustomerCenterConfiguration: NSObject, Codable {
  /// The screen shown when the user has at least one subscription (active or expired) or purchase.
  public var managementScreen: Screen
  /// The screen shown when the user has no purchases at all.
  public var noPurchasesScreen: Screen
  /// Support-related settings (email, app update warning, web management URL).
  public var support: Support
  /// Optional color overrides. `nil` values use system colors.
  public var appearance: Appearance
  /// Shows a "See all purchases" link to the purchase history screen. Defaults to `true`.
  public var showsPurchaseHistory: Bool
  /// Shows the account details section (user ID, original download date). Defaults to `true`.
  public var showsAccountDetails: Bool
  /// Warns when both an App Store and a web subscription are active. Defaults to `true`.
  public var warnsAboutDuplicateSubscriptions: Bool

  public init(
    managementScreen: Screen,
    noPurchasesScreen: Screen,
    support: Support = Support(),
    appearance: Appearance = Appearance(),
    showsPurchaseHistory: Bool = true,
    showsAccountDetails: Bool = true,
    warnsAboutDuplicateSubscriptions: Bool = true
  ) {
    self.managementScreen = managementScreen
    self.noPurchasesScreen = noPurchasesScreen
    self.support = support
    self.appearance = appearance
    self.showsPurchaseHistory = showsPurchaseHistory
    self.showsAccountDetails = showsAccountDetails
    self.warnsAboutDuplicateSubscriptions = warnsAboutDuplicateSubscriptions
  }

  /// A fresh copy of the default configuration: restore, change plan, refund, manage subscription
  /// (with a cancellation survey) and contact support on the management screen; restore on the
  /// no-purchases screen.
  public static var `default`: CustomerCenterConfiguration {
    let cancelSurvey = FeedbackSurvey(
      id: "cancel_survey",
      title: nil,
      options: [
        .init(id: "too_expensive", title: nil),
        .init(id: "dont_use", title: nil),
        .init(id: "bought_by_mistake", title: nil)
      ]
    )
    return CustomerCenterConfiguration(
      managementScreen: Screen(
        title: nil,
        subtitle: nil,
        paths: [
          Path(id: "restore", type: .restore),
          Path(id: "change_plan", type: .changePlan()),
          Path(id: "refund", type: .refund()),
          Path(id: "manage_subscription", type: .manageSubscription, survey: cancelSurvey),
          Path(id: "contact_support", type: .contactSupport)
        ]
      ),
      noPurchasesScreen: Screen(
        title: nil,
        subtitle: nil,
        paths: [Path(id: "restore", type: .restore)]
      )
    )
  }

  override public func isEqual(_ object: Any?) -> Bool {
    guard let other = object as? CustomerCenterConfiguration else { return false }
    return managementScreen == other.managementScreen
      && noPurchasesScreen == other.noPurchasesScreen
      && support == other.support
      && appearance == other.appearance
      && showsPurchaseHistory == other.showsPurchaseHistory
      && showsAccountDetails == other.showsAccountDetails
      && warnsAboutDuplicateSubscriptions == other.warnsAboutDuplicateSubscriptions
  }

  override public var hash: Int {
    var hasher = Hasher()
    hasher.combine(managementScreen)
    hasher.combine(noPurchasesScreen)
    hasher.combine(support)
    hasher.combine(appearance)
    hasher.combine(showsPurchaseHistory)
    hasher.combine(showsAccountDetails)
    hasher.combine(warnsAboutDuplicateSubscriptions)
    return hasher.finalize()
  }

  // MARK: - Screen

  /// A Customer Center screen: a title, optional subtitle and an ordered list of paths.
  @objc(SWKCustomerCenterScreen)
  @objcMembers
  public final class Screen: NSObject, Codable {
    /// Title. `nil` uses the localized default for the screen.
    public var title: String?
    /// Subtitle. `nil` uses the localized default (no-purchases screen) or none (management screen).
    public var subtitle: String?
    /// Ordered paths (actions) shown on the screen.
    public var paths: [Path]

    public init(title: String? = nil, subtitle: String? = nil, paths: [Path]) {
      self.title = title
      self.subtitle = subtitle
      self.paths = paths
    }

    override public func isEqual(_ object: Any?) -> Bool {
      guard let other = object as? Screen else { return false }
      return title == other.title && subtitle == other.subtitle && paths == other.paths
    }

    override public var hash: Int {
      var hasher = Hasher()
      hasher.combine(title)
      hasher.combine(subtitle)
      hasher.combine(paths)
      return hasher.finalize()
    }
  }

  // MARK: - Path

  /// An action row in the Customer Center.
  @objc(SWKCustomerCenterPath)
  @objcMembers
  public final class Path: NSObject, Codable, Identifiable {
    /// Stable identifier, reported in events and delegate callbacks.
    public var id: String
    /// What the path does.
    @nonobjc public var type: PathType
    /// Row title. `nil` uses the localized default for `type`.
    public var title: String?
    /// Optional survey shown before the action runs.
    public var survey: FeedbackSurvey?

    @nonobjc public init(id: String, type: PathType, title: String? = nil, survey: FeedbackSurvey? = nil) {
      self.id = id
      self.type = type
      self.title = title
      self.survey = survey
    }

    override public func isEqual(_ object: Any?) -> Bool {
      guard let other = object as? Path else { return false }
      return id == other.id && type == other.type && title == other.title && survey == other.survey
    }

    override public var hash: Int {
      var hasher = Hasher()
      hasher.combine(id)
      hasher.combine(type)
      hasher.combine(title)
      hasher.combine(survey)
      return hasher.finalize()
    }
  }

  /// The kinds of path the Customer Center supports.
  public enum PathType: Codable, Hashable {
    case restore
    case manageSubscription
    /// `window`: optional seconds since purchase during which a refund may be requested.
    case refund(window: TimeInterval? = nil)
    /// `productIds`: optional subset of the subscription group to offer. `nil` offers the whole group.
    case changePlan(productIds: [String]? = nil)
    case contactSupport
    case url(URL, openMethod: OpenMethod)
    case custom(identifier: String)
  }

  /// How a URL path opens.
  public enum OpenMethod: String, Codable, Hashable {
    case inApp
    case external
  }

  // MARK: - FeedbackSurvey

  /// A single-choice survey shown before a path's action runs.
  @objc(SWKCustomerCenterFeedbackSurvey)
  @objcMembers
  public final class FeedbackSurvey: NSObject, Codable {
    public var id: String
    /// Question text. `nil` uses the localized default ("Why are you cancelling?").
    public var title: String?
    public var options: [Option]

    public init(id: String, title: String?, options: [Option]) {
      self.id = id
      self.title = title
      self.options = options
    }

    override public func isEqual(_ object: Any?) -> Bool {
      guard let other = object as? FeedbackSurvey else { return false }
      return id == other.id && title == other.title && options == other.options
    }

    override public var hash: Int {
      var hasher = Hasher()
      hasher.combine(id)
      hasher.combine(title)
      hasher.combine(options)
      return hasher.finalize()
    }

    @objc(SWKCustomerCenterFeedbackSurveyOption)
    @objcMembers
    public final class Option: NSObject, Codable {
      public var id: String
      /// Option text. `nil` uses the localized default when `id` is one of the built-in ids.
      public var title: String?

      public init(id: String, title: String?) {
        self.id = id
        self.title = title
      }

      override public func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? Option else { return false }
        return id == other.id && title == other.title
      }

      override public var hash: Int {
        var hasher = Hasher()
        hasher.combine(id)
        hasher.combine(title)
        return hasher.finalize()
      }
    }
  }

  // MARK: - Support

  @objc(SWKCustomerCenterSupport)
  @objcMembers
  public final class Support: NSObject, Codable {
    /// Support email for the "Contact support" path. `nil` hides that path.
    public var email: String?
    /// Latest published app version. When set and newer than the installed version, an update banner shows.
    public var latestAppVersion: String?
    /// Whether to show the update banner. Defaults to `true`.
    public var shouldWarnToUpdate: Bool
    /// Whether to look the latest published version up from the App Store when
    /// ``latestAppVersion`` isn't set. Defaults to `true`.
    ///
    /// The lookup is skipped entirely on TestFlight, sandbox and simulator builds, whose version
    /// is normally *ahead* of the App Store — warning those users to "update" would send them to
    /// an older build. It is also skipped when ``latestAppVersion`` is set, which always wins.
    public var checksAppStoreForUpdates: Bool
    /// Overrides the web subscription management page URL used for web-store subscriptions.
    public var webManagementURL: URL?

    public init(
      email: String? = nil,
      latestAppVersion: String? = nil,
      shouldWarnToUpdate: Bool = true,
      checksAppStoreForUpdates: Bool = true,
      webManagementURL: URL? = nil
    ) {
      self.email = email
      self.latestAppVersion = latestAppVersion
      self.shouldWarnToUpdate = shouldWarnToUpdate
      self.checksAppStoreForUpdates = checksAppStoreForUpdates
      self.webManagementURL = webManagementURL
    }

    private enum CodingKeys: String, CodingKey {
      case email, latestAppVersion, shouldWarnToUpdate, checksAppStoreForUpdates, webManagementURL
    }

    /// Hand-written so that `checksAppStoreForUpdates` can default when absent. Everything the
    /// dashboard will eventually serve has to survive being decoded from JSON written before the
    /// key existed; the synthesised decoder would throw instead.
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      email = try container.decodeIfPresent(String.self, forKey: .email)
      latestAppVersion = try container.decodeIfPresent(String.self, forKey: .latestAppVersion)
      shouldWarnToUpdate = try container.decodeIfPresent(Bool.self, forKey: .shouldWarnToUpdate) ?? true
      checksAppStoreForUpdates = try container.decodeIfPresent(Bool.self, forKey: .checksAppStoreForUpdates) ?? true
      webManagementURL = try container.decodeIfPresent(URL.self, forKey: .webManagementURL)
      super.init()
    }

    override public func isEqual(_ object: Any?) -> Bool {
      guard let other = object as? Support else { return false }
      return email == other.email
        && latestAppVersion == other.latestAppVersion
        && shouldWarnToUpdate == other.shouldWarnToUpdate
        && checksAppStoreForUpdates == other.checksAppStoreForUpdates
        && webManagementURL == other.webManagementURL
    }

    override public var hash: Int {
      var hasher = Hasher()
      hasher.combine(email)
      hasher.combine(latestAppVersion)
      hasher.combine(shouldWarnToUpdate)
      hasher.combine(checksAppStoreForUpdates)
      hasher.combine(webManagementURL)
      return hasher.finalize()
    }
  }
}
