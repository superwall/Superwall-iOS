//
//  PathTitleTests.swift
//
//
//  Created by Jordan Morgan on 10/09/2026.
//

import Testing
import Foundation
@testable import SuperwallKit

@Suite("Path row titles")
struct PathTitleTests {
  @available(iOS 15.0, *)
  private func title(
    _ type: CustomerCenterConfiguration.PathType,
    pathTitle: String? = nil,
    destination: ResolvedPathDestination = .restore
  ) -> String {
    let path = CustomerCenterConfiguration.Path(id: "p", type: type, title: pathTitle)
    return PathsListView.title(
      for: ResolvedPath(path: path, destination: destination),
      strings: .english
    )
  }

  /// The bug the required URL title exists to prevent: the host is identical across an app's own
  /// links, so three distinct destinations would render as three identical rows.
  @available(iOS 15.0, *)
  @Test("URL rows on one host still read differently")
  func urlRowsOnTheSameHostAreDistinct() {
    let paths: [CustomerCenterConfiguration.Path] = [
      .url(URL(string: "https://acme.com/faq")!, title: "FAQ"),
      .url(URL(string: "https://acme.com/terms")!, title: "Terms of Service"),
      .url(URL(string: "https://acme.com/privacy")!, title: "Privacy Policy", openMethod: .external)
    ]
    let rows = paths.map { path in
      PathsListView.title(for: ResolvedPath(path: path, destination: .custom("")), strings: .english)
    }

    #expect(rows == ["FAQ", "Terms of Service", "Privacy Policy"])
    #expect(Set(rows).count == 3, "a shared host must not collapse three rows into one label")
  }

  @available(iOS 15.0, *)
  @Test("a URL row without a title falls back to its host")
  func untitledURLRowShowsHost() {
    #expect(title(.url(URL(string: "https://acme.com/faq")!)) == "acme.com")
  }

  /// Every other type names itself, so a title is optional there and overrides the default.
  @available(iOS 15.0, *)
  @Test("built-in types fall back to their localized label")
  func builtInTypesNameThemselves() {
    #expect(title(.restore) == CustomerCenterStrings.english.string("customer_center_path_restore"))
    #expect(title(.refund()) == CustomerCenterStrings.english.string("customer_center_path_refund"))
    #expect(title(.contactSupport) == CustomerCenterStrings.english.string("customer_center_path_contact_support"))
  }

  @available(iOS 15.0, *)
  @Test("an explicit title wins over every default", arguments: [
    CustomerCenterConfiguration.PathType.restore,
    .contactSupport,
    .url(URL(string: "https://acme.com/faq")!, openMethod: .inApp)
  ])
  func explicitTitleWins(type: CustomerCenterConfiguration.PathType) {
    #expect(title(type, pathTitle: "Help me") == "Help me")
  }

  /// The manage row is the one built-in whose label depends on where it leads: a web management
  /// page does more than cancel, so calling it "Cancel subscription" there undersells it.
  @available(iOS 15.0, *)
  @Test("the manage row is named for the store it leads to")
  func manageRowNamedForItsDestination() {
    let appStore = title(.manageSubscription, destination: .appleManageSheet(subscriptionGroupId: nil))
    let web = title(.manageSubscription, destination: .webManageUnavailable)

    #expect(appStore == CustomerCenterStrings.english.string("customer_center_path_manage_subscription"))
    #expect(web == CustomerCenterStrings.english.string("customer_center_path_manage_subscription_web"))
    #expect(appStore != web)
  }

  @available(iOS 15.0, *)
  @Test("an untitled survey asks why you're cancelling only on the manage-subscription path")
  func untitledSurveyTitle() {
    let untitled = CustomerCenterConfiguration.FeedbackSurvey.cancellation
    let cancelQuestion = CustomerCenterStrings.english.string("customer_center_survey_cancel_title")
    #expect(FeedbackSurveyView.title(for: untitled, on: .manageSubscription, strings: .english) == cancelQuestion)
    #expect(FeedbackSurveyView.title(for: untitled, on: .refund, strings: .english) == "")
    #expect(FeedbackSurveyView.title(for: untitled, on: .restore, strings: .english) == "")

    let titled = CustomerCenterConfiguration.FeedbackSurvey(id: "s", title: "Tell us more", options: [.tooExpensive])
    #expect(FeedbackSurveyView.title(for: titled, on: .refund, strings: .english) == "Tell us more")
    #expect(FeedbackSurveyView.title(for: titled, on: .manageSubscription, strings: .english) == "Tell us more")
  }
}

