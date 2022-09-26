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
    _ paywallStatePublisher: PassthroughSubject<PaywallState, Never>
  ) -> AnyPublisher<PresentablePipelineData, Error> {
    self
      .flatMap { request, debugInfo, paywallViewController, presenter in
        Future {
          await MainActor.run {
            paywallViewController.present(
              on: presenter,
              eventData: request.presentationInfo.eventData,
              presentationStyleOverride: request.paywallOverrides?.presentationStyle,
              paywallStatePublisher: paywallStatePublisher
            ) { success in
              if success {
                /*self.presentAgain = {
                  if let presentingPaywallIdentifier = paywallViewController.paywallResponse.identifier {
                    PaywallManager.shared.removePaywall(withIdentifier: presentingPaywallIdentifier)
                  }
                  await internallyPresent(
                    presentationInfo,
                    on: presentingViewController,
                    cached: false,
                    paywallOverrides: paywallOverrides,
                    paywallState: paywallState
                  )
                }*/

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
            }
            return (request, debugInfo, paywallViewController, presenter)
          }
        }
      }
      .eraseToAnyPublisher()
  }
}
