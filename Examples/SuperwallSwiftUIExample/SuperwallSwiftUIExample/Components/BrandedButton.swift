//
//  BrandedButton.swift
//  SuperwallSwiftUIExample
//
//  Created by Yusuf Tör on 11/03/2022.
//

import SwiftUI

struct BrandedButton: View {
  let title: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Text(title)
        .font(.rubikBold(.five))
        .foregroundColor(.neutral)
        .padding([.top, .bottom])
        .contentShape(Rectangle())
        .frame(maxWidth: .infinity)
    }
    .background(Color.primaryTeal)
    .clipShape(Capsule())
    .frame(maxWidth: 500)
  }
}

struct BrandedButton_Previews: PreviewProvider {
  static var previews: some View {
    BrandedButton(title: "Test button") {}
    .background(Color.neutral)
    .previewLayout(.sizeThatFits)
  }
}
