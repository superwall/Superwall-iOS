//
//  InfoView.swift
//  SuperwallSwiftUIExample
//
//  Created by Yusuf Tör on 16/03/2022.
//

import SwiftUI

struct InfoView: View {
  var text: String

  var body: some View {
    Text("\(Image(systemName: "info.circle.fill")) \(text)"
    )
    .lineSpacing(5)
    .multilineTextAlignment(.center)
    .padding(.horizontal)
    .padding(.top, 48)
  }
}

struct InfoView_Previews: PreviewProvider {
  static var previews: some View {
    InfoView(text: "example")
      .previewLayout(.sizeThatFits)
  }
}
