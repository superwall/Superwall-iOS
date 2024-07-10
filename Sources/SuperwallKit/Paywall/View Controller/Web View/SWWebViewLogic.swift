//
//  File.swift
//  
//
//  Created by Yusuf Tör on 27/06/2024.
//

import Foundation

enum SWWebViewLogic {
  static func chooseEndpoint(
    from endpoints: [WebViewEndpoint]
  ) -> WebViewEndpoint? {
    // Check if the endpoints array is empty. If it is, return nil.
    if endpoints.isEmpty {
      return nil
    }

    // Calculate the sum of the percentages of all endpoints.
    let endpointPercentageSum = endpoints.reduce(0) { partialResult, endpoint in
      partialResult + endpoint.percentage
    }

    // If the sum of the percentages is 0 or less, return a random endpoint's URL.
    if endpointPercentageSum <= 0 {
      return endpoints.randomElement()
    }

    // Generate a random number between 0 and endpoint percentage sum.
    let randomNumber = Double.random(in: 0..<endpointPercentageSum)

    // Normalize the random number by dividing it by the sum of the percentages.
    let normRandomPercentage = randomNumber / endpointPercentageSum

    var totalNormUrlPercentage = 0.0

    // Iterate through the endpoints to find the one that matches the random percentage.
    for endpoint in endpoints {
      // Normalize the endpoint's percentage by dividing it by the sum of the percentages.
      let normEndpointPercentage = endpoint.percentage / endpointPercentageSum

      // Accumulate the normalized percentage.
      totalNormUrlPercentage += normEndpointPercentage

      // If the normalized random percentage is less than the accumulated percentage, return the endpoint's URL.
      if normRandomPercentage < totalNormUrlPercentage {
        return endpoint
      }
    }

    // If no endpoint was selected (which shouldn't happen), return nil.
    return nil
  }
}
