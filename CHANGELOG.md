# CHANGELOG

The changelog for `Paywall`. Also see the [releases](https://github.com/superwall-me/paywall-ios/releases) on GitHub.


2.3.0 (upcoming release)
-----

### Enhancements
- New [UIKit Example App](Examples/SuperwallUIKitExample).
- Better [SDK documentation](https://sdk.superwall.me/documentation/paywall/). This is built from the ground up using DocC which means you view it directly in Xcode by selecting **Product ▸ Build Documentation**.
- New Pull Request and Bug Report templates for the repo.
- Added a setup file that installs GitHooks as well as SwiftLint if you don't already have it. This is located at `scripts/setup.sh` and can be run from anywhere.
- Added a [CONTIBUTING.md](CONTRIBUTING.md) file for detailed instructions on how to get set up and contribute to the codebase.
- Added a [Code of Conduct](CODE_OF_CONDUCT.md) file to the repo.
- Added a CHANGELOG.md file.
- Removed the `TPInnAppReceipt` dependency for the SDK.


### Fixes
- All readme links for the UIKit example app now work.
- Exposes `experimentId` and `variantId` whenever `PaywallInfo` is returned in SDK callbacks. This will be useful in the next version of Triggers.
