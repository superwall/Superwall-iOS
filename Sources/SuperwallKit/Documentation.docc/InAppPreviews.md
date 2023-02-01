# In-App Previews

Previewing a paywall on device from the Superwall dashboard.

## Overview

You can preview your paywall on-device before going live by utilizing paywall previews. First, you need to add a custom URL scheme to your app. Then you need to handle the deep link when your app is opened via deep link using ``Superwall/handleDeepLink(_:)``. You can then preview your paywall by accessing your paywall from the dashboard, clicking the preview button, and scanning the QR code that appears.

## Adding a Custom URL Scheme

In your `info.plist`, you'll need to add a custom URL scheme for your app:

![Adding a custom URL Scheme for your app](customUrlScheme.png)

You can view [Apple's documentation](https://developer.apple.com/documentation/xcode/defining-a-custom-url-scheme-for-your-app) to learn more about how to do that.

Then, you'll need to handle the deep link within your app using ``Superwall/handleDeepLink(_:)``. You'll need to call this when your app is opened via a deep link. There are different ways to do this, depending on whether you're using a SceneDelegate, AppDelegate, or writing an app in SwiftUI.

### Handling a Deep Link in SwiftUI

Inside your main App file, attach `onOpenURL(perform:)` to a view then handle your deep link. Your file might look something like this:

```swift
@main
struct MyApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  
  var body: some Scene {
    WindowGroup {
      ContentView()
        .onOpenURL { url in
          Superwall.shared.handleDeepLink(url)
        }
    }
  }
}
```

Then, build and run your app on your phone.

### Handling a Deep Link from the AppDelegate

Inside `AppDelegate.swift`, add:

```swift
func application(
  _ app: UIApplication, 
  open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]
) -> Bool {
  return Superwall.shared.handleDeepLink(url)
}
```

Then, build and run your app on your phone.

### Handling a Deep Link from the Scene Delegate

Inside `SceneDelegate.swift`, add:

```swift
// for cold launches
func scene(
  _ scene: UIScene, 
  willConnectTo session: UISceneSession, 
  options connectionOptions: UIScene.ConnectionOptions
) {
  ...
  
  for context in connectionOptions.urlContexts {
    Superwall.shared.handleDeepLink(context.url)
  }
}

// for when your app is already running
func scene(
  _ scene: UIScene, 
  openURLContexts URLContexts: Set<UIOpenURLContext>
) {
  for context in URLContexts {
    Superwall.shared.handleDeepLink(context.url)
  }
}
```

Then, build and run your app on your phone.

## Previewing From the Dashboard

Open the [Superwall Dashboard](https://superwall.com/dashboard). Click on the **cog icon** in the top right corner, then select **Settings**:

![Opening the dashboard settings](settings.png)

With the **General** tab selected, type your custom URL scheme, without slashes, into the **Apple URL Scheme** field:

![Opening the dashboard settings](dashboardUrlScheme.png)

Next, open your paywall from the dashboard and click **Preview**. You'll see a QR code appear in a pop-up:

![Paywall preview QR code](qrCode.png)

On your device, scan this QR code. You can do this via Apple's Camera app. This will take you to a paywall viewer within your app, where you can preview all your paywalls in different configurations.
