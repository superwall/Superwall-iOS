//
//  Platform.swift
//  SuperwallKit
//
//  Created by Brian Anglin on 13/10/2026.
//
// Names for the UI types that differ between UIKit and AppKit, so code shared
// by iOS, Mac Catalyst, visionOS and native macOS can refer to one type.

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
typealias ApplicationState = UIApplication.State
#endif
