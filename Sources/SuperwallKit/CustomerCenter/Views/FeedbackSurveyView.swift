//
//  FeedbackSurveyView.swift
//
//
//  Created by Claude on 20/08/2026.
//

import SwiftUI

@available(iOS 15.0, *)
struct FeedbackSurveyView: View {
  @ObservedObject var viewModel: CustomerCenterViewModel
  @Environment(\.customerCenterStrings) private var strings
  @State private var answering: String?

  var body: some View {
    NavigationView {
      List {
        if let survey = viewModel.pendingSurvey?.survey {
          ForEach(survey.options, id: \.id) { option in
            Button {
              guard answering == nil else { return }
              answering = option.id
              Task { await viewModel.answerSurvey(optionId: option.id) }
            } label: {
              HStack { Text(optionTitle(option)); Spacer(); if answering == option.id { ProgressView() } }
            }
            .disabled(answering != nil)
            .accessibilityIdentifier("customer_center.survey.option.\(option.id)")
          }
        }
      }
      .listStyle(.insetGrouped)
      .navigationTitle(viewModel.pendingSurvey?.survey.title ?? strings.string("customer_center_survey_cancel_title"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button(strings.string("customer_center_cancel")) { viewModel.cancelSurvey() }
            .accessibilityIdentifier("customer_center.survey.cancel")
        }
      }
    }
    .navigationViewStyle(.stack)
    .interactiveDismissDisabled(answering != nil)
  }

  private func optionTitle(_ option: CustomerCenterConfiguration.FeedbackSurvey.Option) -> String {
    if let title = option.title { return title }
    switch option.id {
    case "too_expensive": return strings.string("customer_center_survey_too_expensive")
    case "dont_use": return strings.string("customer_center_survey_dont_use")
    case "bought_by_mistake": return strings.string("customer_center_survey_bought_by_mistake")
    default: return option.id
    }
  }
}
