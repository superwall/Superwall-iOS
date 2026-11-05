//
//  Platform.swift
//  SuperwallKit
//
//  Created by Brian Anglin on 13/10/2026.
//
// Names for the UI types that differ between UIKit, AppKit and WatchKit, so
// code shared by every platform can refer to one type.

#if os(macOS)
import AppKit

/// The view controller type the SDK's views are built on.
///
/// `NSViewController` on macOS and `UIViewController` everywhere else.
/// ``PaywallViewController`` is a subclass of it.
public typealias PlatformViewController = NSViewController

typealias PlatformView = NSView
typealias PlatformColor = NSColor
typealias PlatformImage = NSImage
typealias PlatformWindow = NSWindow
typealias PlatformApplication = NSApplication
typealias PlatformButton = NSButton
#elseif os(watchOS)
import UIKit
import WatchKit

// watchOS has no view controllers, windows or web views, so it has no paywall
// UI. Only the types the shared code needs exist here.
typealias PlatformColor = UIColor
typealias PlatformImage = UIImage
typealias PlatformApplication = WKExtension
typealias PlatformDevice = WKInterfaceDevice
typealias ApplicationState = WKApplicationState

/// Stands in for a view controller in internal code shared with the UIKit
/// platforms. It has no cases, so it can never be passed.
enum PlatformViewController {}
#else
import UIKit

/// The view controller type the SDK's views are built on.
///
/// `NSViewController` on macOS and `UIViewController` everywhere else.
/// ``PaywallViewController`` is a subclass of it.
public typealias PlatformViewController = UIViewController

typealias PlatformView = UIView
typealias PlatformColor = UIColor
typealias PlatformImage = UIImage
typealias PlatformWindow = UIWindow
typealias PlatformApplication = UIApplication
typealias PlatformButton = UIButton
typealias PlatformDevice = UIDevice
typealias ApplicationState = UIApplication.State
#endif
