//
//  PresentationTypeListView.swift
//  SuperwallSwiftUIExample
//
//  Created by Yusuf Tör on 11/03/2022.
//

import SwiftUI

struct PaywallOptionsTableView: View {
  init() {
    UINavigationBar.appearance().titleTextAttributes = [
      .foregroundColor: UIColor.white,
      .font: UIFont.rubikBold(.five)
    ]
  }

  var body: some View {
    ZStack {
      VStack(spacing: 40) {
        information()
        PaywallOptionsListView()
        Spacer()
      }
      .background(Color.neutral)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .principal) {
          logo()
        }
      }
      .navigationTitle("")
      .padding(.top)
    }
    .background(Color.neutral)
  }

  private func logo() -> some View {
    VStack(spacing: 0) {
      Image("logo")
        .resizable()
        .scaledToFit()
        .frame(width: 200)
      Text("Example app")
        .foregroundColor(.white)
        .italic()
    }
  }

  private func information() -> some View {
    Text("Hi \(PaywallService.name)!")
      .padding(.top)
      .foregroundColor(.white)
  }
}

struct PaywallOptionsTableView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      PaywallOptionsTableView()
    }
  }
}
