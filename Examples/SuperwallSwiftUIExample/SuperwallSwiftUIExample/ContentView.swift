//
//  ContentView.swift
//  SuperwallSwiftUIExample
//
//  Created by Yusuf Tör on 10/03/2022.
//

import SwiftUI
import Paywall

struct ContentView: View {
  @State var showPaywall = false

  var body: some View {
    VStack {
      Button(
        action: {
          showPaywall.toggle()
        },
        label: {
          Text("Toggle Paywall")
        }
      )
      .padding()
    }
    .presentPaywall(
      isPresented: $showPaywall,
      onPresent: { paywallInfo in
        print("paywall info is", paywallInfo)
      },
      onDismiss: { result in
        switch result.state {
        case .closed:
          print("User dismissed the paywall.")
        case .purchased(productId: let productId):
          print("Purchased a product with id \(productId), then dismissed.")
        case .restored:
          print("Restored purchases, then dismissed.")
        }
      },
      onFail: { error in
        print("did fail")
      }
    )
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
  }
}
