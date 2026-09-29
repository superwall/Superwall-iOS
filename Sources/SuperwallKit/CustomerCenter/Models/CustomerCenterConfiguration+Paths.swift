//
//  CustomerCenterConfiguration+Paths.swift
//
//
//  Created by Yusuf Tör on 23/09/2026.
//

import Foundation
import UIKit

extension CustomerCenterConfiguration.PathType {
  /// The ID a path gets when none is given: the type's name for the built-in types, the URL's host
  /// and path for a URL path, and the identifier for a custom path.
  ///
  /// A URL path leaves out the query and fragment because the ID is reported in analytics, and a
  /// query can carry a token.
  public var defaultId: String {
    switch self {
    case .restore: return "restore"
    case .manageSubscription: return "manage_subscription"
    case .refund: return "refund"
    case .changePlan: return "change_plan"
    case .contactSupport: return "contact_support"
    case let .url(url, _): return url.withoutQueryOrFragment.hostAndPath
    case .custom(let identifier): return identifier
    }
  }
}

extension CustomerCenterConfiguration {
  /// Path IDs that appear more than once on the same screen. Rows and events are told apart by
  /// ID, so a repeated one makes two rows indistinguishable.
  var duplicatePathIds: [String] {
    [managementScreen, noPurchasesScreen].flatMap { screen in
      Dictionary(grouping: screen.paths, by: \.id).filter { $0.value.count > 1 }.keys.sorted()
    }
  }

  /// IDs of URL paths with no title, which fall back to showing the URL's host.
  var untitledURLPathIds: [String] {
    (managementScreen.paths + noPurchasesScreen.paths).compactMap { path in
      guard case .url = path.type, path.title == nil else { return nil }
      return path.id
    }
  }

  /// IDs of paths whose survey has no title and so would show none: only a manage-subscription
  /// path has a default question.
  var untitledSurveyPathIds: [String] {
    (managementScreen.paths + noPurchasesScreen.paths).compactMap { path in
      guard let survey = path.survey, survey.title == nil else { return nil }
      if case .manageSubscription = path.type {
        return nil
      }
      return path.id
    }
  }

  /// Accent colour strings that aren't valid `#RRGGBB` or `#RRGGBBAA` hex, and so are ignored.
  var invalidAccentHexes: [String] {
    guard let accent = appearance.accent else { return [] }
    return [accent.light, accent.dark].filter { UIColor(hex: $0) == nil }
  }

  /// Logs configuration mistakes that still render, just badly.
  func warnAboutConfigurationProblems() {
    let duplicates = duplicatePathIds
    if !duplicates.isEmpty {
      Logger.debug(
        logLevel: .warn,
        scope: .customerCenter,
        message: "Customer Center paths share an id on the same screen: \(duplicates.joined(separator: ", ")). "
          + "Pass a distinct `id` to each."
      )
    }
    let untitled = untitledURLPathIds
    if !untitled.isEmpty {
      Logger.debug(
        logLevel: .warn,
        scope: .customerCenter,
        message: "Customer Center URL paths have no title and will show the URL's host: "
          + "\(untitled.joined(separator: ", ")). Give each a `title`."
      )
    }
    let untitledSurveys = untitledSurveyPathIds
    if !untitledSurveys.isEmpty {
      Logger.debug(
        logLevel: .warn,
        scope: .customerCenter,
        message: "Customer Center surveys on these paths have no title, so they'll show no question: "
          + "\(untitledSurveys.joined(separator: ", ")). Give each survey a `title`."
      )
    }
    let invalidHexes = invalidAccentHexes
    if !invalidHexes.isEmpty {
      Logger.debug(
        logLevel: .warn,
        scope: .customerCenter,
        message: "Customer Center accent colours aren't valid hex and will be ignored: "
          + "\(invalidHexes.joined(separator: ", ")). Use #RRGGBB or #RRGGBBAA."
      )
    }
  }
}

// MARK: - Path shorthands

/// Lets a screen list its paths as `.restore`, `.refund(window: 86_400)`,
/// `.url(faqURL, title: "FAQ")` and so on, rather than spelling out `Path(type:)` each time.
public extension CustomerCenterConfiguration.Path {
  @nonobjc static var restore: CustomerCenterConfiguration.Path { restore() }
  @nonobjc static var manageSubscription: CustomerCenterConfiguration.Path { manageSubscription() }
  @nonobjc static var refund: CustomerCenterConfiguration.Path { refund() }
  @nonobjc static var changePlan: CustomerCenterConfiguration.Path { changePlan() }
  @nonobjc static var contactSupport: CustomerCenterConfiguration.Path { contactSupport() }

  @nonobjc static func restore(id: String? = nil, title: String? = nil, survey: CustomerCenterConfiguration.FeedbackSurvey? = nil) -> CustomerCenterConfiguration.Path {
    CustomerCenterConfiguration.Path(id: id, type: .restore, title: title, survey: survey)
  }

  @nonobjc static func manageSubscription(
    id: String? = nil,
    title: String? = nil,
    survey: CustomerCenterConfiguration.FeedbackSurvey? = nil
  ) -> CustomerCenterConfiguration.Path {
    CustomerCenterConfiguration.Path(id: id, type: .manageSubscription, title: title, survey: survey)
  }

  /// - Parameter window: Seconds since purchase during which a refund may be requested.
  @nonobjc static func refund(
    window: TimeInterval? = nil,
    id: String? = nil,
    title: String? = nil,
    survey: CustomerCenterConfiguration.FeedbackSurvey? = nil
  ) -> CustomerCenterConfiguration.Path {
    CustomerCenterConfiguration.Path(id: id, type: .refund(window: window), title: title, survey: survey)
  }

  /// - Parameter productIds: The subset of the subscription group to offer. `nil` offers the whole group.
  @nonobjc static func changePlan(
    productIds: [String]? = nil,
    id: String? = nil,
    title: String? = nil,
    survey: CustomerCenterConfiguration.FeedbackSurvey? = nil
  ) -> CustomerCenterConfiguration.Path {
    CustomerCenterConfiguration.Path(id: id, type: .changePlan(productIds: productIds), title: title, survey: survey)
  }

  @nonobjc static func contactSupport(
    id: String? = nil,
    title: String? = nil,
    survey: CustomerCenterConfiguration.FeedbackSurvey? = nil
  ) -> CustomerCenterConfiguration.Path {
    CustomerCenterConfiguration.Path(id: id, type: .contactSupport, title: title, survey: survey)
  }

  /// - Parameters:
  ///   - title: What the row says. Required: a URL has no name the SDK could give it.
  ///   - openMethod: Opens in an in-app browser by default.
  @nonobjc static func url(
    _ url: URL,
    title: String,
    openMethod: CustomerCenterConfiguration.OpenMethod = .inApp,
    id: String? = nil,
    survey: CustomerCenterConfiguration.FeedbackSurvey? = nil
  ) -> CustomerCenterConfiguration.Path {
    CustomerCenterConfiguration.Path(
      id: id,
      type: .url(url, openMethod: openMethod),
      title: title,
      survey: survey
    )
  }

  /// - Parameter identifier: Passed back in ``CustomerCenterAction/custom(identifier:)`` when tapped.
  @nonobjc static func custom(
    identifier: String,
    title: String? = nil,
    id: String? = nil,
    survey: CustomerCenterConfiguration.FeedbackSurvey? = nil
  ) -> CustomerCenterConfiguration.Path {
    CustomerCenterConfiguration.Path(id: id, type: .custom(identifier: identifier), title: title, survey: survey)
  }
}

extension URL {
  /// The URL with any query and fragment removed, for reporting: either can carry a token.
  var withoutQueryOrFragment: URL {
    guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else { return self }
    components.query = nil
    components.fragment = nil
    components.user = nil
    components.password = nil
    return components.url ?? self
  }

  /// Host and path, as in `app.com/faq`, or the whole URL when it has neither.
  var hostAndPath: String {
    let value = (host ?? "") + path
    return value.isEmpty ? absoluteString : value
  }
}
