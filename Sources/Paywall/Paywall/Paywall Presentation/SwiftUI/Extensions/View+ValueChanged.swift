//
//  File.swift
//  
//
//  Created by Yusuf Tör on 10/03/2022.
//

import SwiftUI
import Combine

@available(iOS 13.0, *)
extension View {
  /// A backwards compatible wrapper for iOS 14 `onChange`
  @ViewBuilder func valueChanged<T: Equatable>(
    value: T,
    onChange: @escaping (T) -> Void
  ) -> some View {
    if #available(iOS 14.0, *) {
      self.onChange(
        of: value,
        perform: onChange
      )
    } else {
      self.onReceive(Just(value)) { value in
        onChange(value)
      }
    }
  }
}
