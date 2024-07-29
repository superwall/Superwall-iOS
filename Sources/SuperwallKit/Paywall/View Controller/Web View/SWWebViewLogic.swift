//
//  File.swift
//  
//
//  Created by Yusuf Tör on 27/06/2024.
//

import Foundation

enum SWWebViewLogic {
  static func chooseEndpoint(
    from endpoints: [WebViewEndpoint],
    randomiser: (Range<Double>) -> Double = Double.random(in:)
  ) -> WebViewEndpoint? {
    // Check if the endpoints array is empty. If it is, return nil.
    if endpoints.isEmpty {
      return nil
    }

    // Calculate the sum of the percentages of all endpoints.
    let endpointPercentageSum = endpoints.reduce(0) { $0 + $1.percentage }

    // If the sum of the percentages is 0 or less, return a random endpoint's URL.
    if endpointPercentageSum <= 0 {
      let randomEndpointIndex = randomiser(0..<Double(endpoints.count))
      return endpoints[Int(randomEndpointIndex)]
    }

    // Generate a random number between 0 and endpoint percentage sum.
    let randomNumber = Double.random(in: 0..<endpointPercentageSum)

    var accumulatedPercentage = 0.0

    // Iterate through the endpoints to find the one that matches the random percentage.
    for endpoint in endpoints {
      accumulatedPercentage += endpoint.percentage
      if randomNumber < accumulatedPercentage {
        return endpoint
      }
    }

    // If no endpoint was selected (which shouldn't happen), return nil.
    return nil
  }
}
