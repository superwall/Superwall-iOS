//
//  StoreDebugInterceptor.swift
//  SuperwallKit
//
//  Created by Superwall on 03/11/2026.
//

import Foundation

/// Logs every action dispatch, action execution and state update of a
/// ``SequentialStore``, giving a timeline of what happened and why:
///
/// ```
/// [Identity] action → identify(userId: "user_123")
/// [Identity] update → identify | 0.1ms
/// [Identity] action ✓ identify(userId: "user_123") | 2.3ms
/// ```
enum StoreDebugInterceptor {
  static func install<Context, State>(
    on store: SequentialStore<Context, State>,
    name: String,
    scope: LogScope,
    logLevel: LogLevel = .debug
  ) {
    store.onUpdate { reducer, next in
      let start = DispatchTime.now()
      next()
      Logger.debug(
        logLevel: logLevel,
        scope: scope,
        message: "[\(name)] update → \(label(of: reducer)) | \(milliseconds(since: start))"
      )
    }

    store.onAction { action, next in
      Logger.debug(
        logLevel: logLevel,
        scope: scope,
        message: "[\(name)] action → \(label(of: action))"
      )
      next()
    }

    store.onActionExecution { action, next in
      let start = DispatchTime.now()
      await next()
      Logger.debug(
        logLevel: logLevel,
        scope: scope,
        message: "[\(name)] action ✓ \(label(of: action)) | \(milliseconds(since: start))"
      )
    }
  }

  private static func label(of value: Any) -> String {
    String(describing: value)
  }

  private static func milliseconds(since start: DispatchTime) -> String {
    let nanoseconds = DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds
    return String(format: "%.1fms", Double(nanoseconds) / 1_000_000)
  }
}
