//
//  File.swift
//  
//
//  Created by Yusuf Tör on 26/09/2022.
//

import UIKit
import Combine

extension AnyPublisher where Output == PresentablePipelineData, Failure == Error {
  func presentPaywall(
    _ paywallStatePublisher: PassthroughSubject<PaywallState, Never>,
    _ presentationPublisher: CurrentValueSubject<PaywallPresentationRequest, Error>
  ) -> AnyPublisher<PresentablePipelineData, Error> {
    self
      .flatMap { request, debugInfo, paywallViewController, presenter in
        Future { promise in
          Task {
            await MainActor.run {
              paywallViewController.present(
                on: presenter,
                eventData: request.presentationInfo.eventData,
                presentationStyleOverride: request.paywallOverrides?.presentationStyle,
                paywallStatePublisher: paywallStatePublisher,
                presentationPublisher: presentationPublisher
              ) { isPresented in

                if isPresented {
                  Paywall.shared.lastSuccessfulPresentationRequest = request
                  let state: PaywallState = .presented(paywallViewController.paywallInfo)
                  paywallStatePublisher.send(state)
                } else {
                  Logger.debug(
                    logLevel: .info,
                    scope: .paywallPresentation,
                    message: "Paywall Already Presented",
                    info: debugInfo
                  )
                }
                promise(.success((request, debugInfo, paywallViewController, presenter)))
              }
            }
          }
        }
      }
      .eraseToAnyPublisher()
  }
}
