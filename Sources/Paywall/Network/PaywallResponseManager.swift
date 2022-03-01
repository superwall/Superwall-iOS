//
//  File.swift
//  
//
//  Created by Jake Mor on 10/19/21.
//

import Foundation
import StoreKit
import TPInAppReceipt

final class PaywallResponseManager: NSObject {
	static var shared = PaywallResponseManager()

	private var cachedResponsesByIdentifier: [String: PaywallResponse] = [:]
	private let queue = DispatchQueue(label: "PaywallRequests")
	private var responsesByHash: [String: (PaywallResponse?, NSError?)] = [:]
	private var handlersByHash: [String: [(PaywallResponse?, NSError?) -> Void]] = [:]

	func requestHash(identifier: String? = nil, event: EventData? = nil) -> String {
		return "\((identifier ?? event?.name ?? "$called_manually"))_\(DeviceHelper.shared.locale)"
	}

  // swiftlint:disable:next cyclomatic_complexity function_body_length
	func getResponse(
    identifier: String? = nil,
    event: EventData? = nil,
    completion: @escaping (PaywallResponse?, NSError?) -> Void
  ) {
    var experimentId: String?
    var variantId: String?
    var identifier = identifier

		// if we're requesting a response for a trigger/event that wasn't in the initial config endpoint, ignore it
		if Paywall.shared.didFetchConfig, let eventName = event?.name {
      let triggerResponse = TriggerManager.shared.handleEvent(eventName: eventName, eventData: event)
      switch triggerResponse {
      // Do nothing, continue with loading as expected
      case .presentV1:
        break
      case let .presentIdentifier(experimentIdentifier, variantIdentifier, paywallIdentifier):
        identifier = paywallIdentifier
        experimentId = experimentIdentifier
        variantId = variantIdentifier
        // Paywall.track(.paywallResponseLoadComplete(fromEvent: isFromEvent, event: event, paywallInfo: response.getPaywallInfo(fromEvent: event)))
        Paywall.track(
          .triggerFire(
            triggerInfo: TriggerInfo(
              result: "present",
              experimentId: experimentId,
              variantId: variantId,
              paywallIdentifier: identifier
            )
          )
        )
      case let .holdout(experimentId, variantId):
        let userInfo: [String: Any] = [
          "experimentId": experimentId,
          "variantId": variantId,
          NSLocalizedDescriptionKey: NSLocalizedString(
            "Trigger Holdout",
            value: "This user was assigned to a holdout in a trigger experiment",
            comment: "ExperimentId: \(experimentId) VariantId: \(variantId)"
          )
        ]
        let error = NSError(domain: "com.superwall", code: 4001, userInfo: userInfo)
        Paywall.track(
          .triggerFire(
            triggerInfo:
              TriggerInfo(
                result: "holdout",
                experimentId: experimentId,
                variantId: variantId,
                paywallIdentifier: nil
              )
          )
        )
        completion(nil, error)
        return
      case .noRuleMatch:
        let userInfo: [String: Any] = [
          NSLocalizedDescriptionKey: NSLocalizedString(
            "No rule match",
            value: "The user did not match any rules configured for this trigger",
            comment: ""
          )
        ]
        let error = NSError(domain: "com.superwall", code: 4000, userInfo: userInfo)
        Paywall.track(
          .triggerFire(
            triggerInfo:
              TriggerInfo(
                result: "no_rule_match",
                experimentId: nil,
                variantId: nil,
                paywallIdentifier: nil
              )
          )
        )
        completion(nil, error)
        return
      case .unknownEvent:
        // create the error
        let userInfo: [String: Any] = [
          NSLocalizedDescriptionKey: NSLocalizedString(
            "Trigger Disabled",
            value: "There isn't a paywall configured to show in this context",
            comment: ""
          )
        ]
        let error = NSError(domain: "SWTriggerDisabled", code: 404, userInfo: userInfo)
        completion(nil, error)
        return
      }
		}

		let hash = requestHash(identifier: identifier, event: event)

		// if the response exists, return it
		if let (response, error) = responsesByHash[hash],
      !SWDebugManager.shared.isDebuggerLaunched {
			onMain {
        var response = response
        response?.experimentId = experimentId
        response?.variantId = variantId
				completion(response, error)
			}
			return
		}

		// if the request is in progress, enque the completion handler
		if let handlers = handlersByHash[hash] {
			handlersByHash[hash] = handlers + [completion] // to execute all completion handlers
      //  handlersByHash[hash] = [completion] // to only execute the last completion handler
			return
		}

		// if there are no requests in progress
		handlersByHash[hash] = [completion]

		queue.async {
			let isFromEvent = event != nil

			let responseLoadStartTime = Date()
			Paywall.track(.paywallResponseLoadStart(fromEvent: isFromEvent, event: event))

			// get the paywall

			Network.shared.paywall(withIdentifier: identifier, fromEvent: event) { result in
				self.queue.async {
          switch result {
          case .success(var response):
            response.experimentId = experimentId
            response.variantId = variantId
            response.responseLoadStartTime = responseLoadStartTime
            response.responseLoadCompleteTime = Date()

            Paywall.track(
              .paywallResponseLoadComplete(
                fromEvent: isFromEvent,
                event: event,
                paywallInfo: response.getPaywallInfo(fromEvent: event)
              )
            )

            response.productsLoadStartTime = Date()

            Paywall.track(
              .paywallProductsLoadStart(
                fromEvent: isFromEvent,
                event: event,
                paywallInfo: response.getPaywallInfo(fromEvent: event)
              )
            )

            // add its products
            StoreKitManager.shared.get(productsWithIds: response.productIds) { productsById in
              var variables: [Variable] = []
              var productVariables: [ProductVariable] = []
              //  var response = response
              for product in response.products {
                if let appleProduct = productsById[product.id] {
                  variables.append(Variable(key: product.type.rawValue, value: appleProduct.eventData))
                  productVariables.append(
                    ProductVariable(
                      key: product.type.rawValue,
                      value: appleProduct.productVariables
                    )
                  )

                  if product.type == .primary {
                    response.isFreeTrialAvailable = appleProduct.hasFreeTrial
                    if let receipt = try? InAppReceipt.localReceipt() {
                      let hasPurchased = receipt.containsPurchase(ofProductIdentifier: product.id)
                      if hasPurchased && appleProduct.hasFreeTrial {
                        response.isFreeTrialAvailable = false
                      }
                    }
                    // use the override if it is set
                    if let freeTrialOverride = Paywall.isFreeTrialAvailableOverride {
                      response.isFreeTrialAvailable = freeTrialOverride
                      Paywall.isFreeTrialAvailableOverride = nil // reset it for future use
                    }
                  }
                }
              }

              response.variables = variables
              response.productVariables = productVariables

              // cache the response for later
              self.responsesByHash[hash] = (response, nil)

              // execulte all the cached handlers
              if let handlers = self.handlersByHash[hash] {
                onMain {
                  for handler in handlers {
                    handler(response, nil)
                  }
                }
              }

              // reset the handler cache
              self.handlersByHash.removeValue(forKey: hash)

              response.productsLoadCompleteTime = Date()
              Paywall.track(
                .paywallProductsLoadComplete(
                  fromEvent: isFromEvent,
                  event: event,
                  paywallInfo: response.getPaywallInfo(fromEvent: event)
                )
              )
            }
          case .failure(let error):
            if let error = error as? Network.Error, error == .notFound {
              Paywall.track(.paywallResponseLoadNotFound(fromEvent: isFromEvent, event: event))
            } else {
              Paywall.track(.paywallResponseLoadFail(fromEvent: isFromEvent, event: event))
            }

            // create the error
            let userInfo: [String: Any] = [
              NSLocalizedDescriptionKey: NSLocalizedString(
                "Not Found",
                value: "There isn't a paywall configured to show in this context",
                comment: ""
              )
            ]
            let error = NSError(domain: "SWPaywallNotFound", code: 404, userInfo: userInfo)

            // cache the response for later
            //  self.responsesByHash[hash] = (nil, error)

            // execulte all the cached handlers
            if let handlers = self.handlersByHash[hash] {
              onMain {
                for handler in handlers {
                  handler(nil, error)
                }
              }

              // reset the handler cache
              self.handlersByHash.removeValue(forKey: hash)
            }
          }
				}
			}
		}
	}

	func getPaywallResponses(config: ConfigResponse) {}
}
