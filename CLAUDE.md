# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Setup
- Run `scripts/setup.sh` to initialize the development environment - installs SwiftLint and sets up git hooks
- Install `xcodegen` if not already installed: `brew install xcodegen`
- Pre-commit hooks automatically run `xcodegen` and update podspec version from Constants.swift

### Building and Testing
- **Build**: 
  - Xcode: Open `SuperwallKit.xcodeproj` in Xcode (auto-generated from `project.yml`)
  - Command Line: Use `scripts/build.sh` to build the framework via xcodebuild (automatically runs xcodegen)
- **Tests**: 
  - Xcode: Run tests using the `SuperwallKitTests` scheme in Xcode
  - Command Line: Use `scripts/test.sh` to run tests via xcodebuild (automatically runs xcodegen)
- **Linting**: Use `scripts/lint.sh` to run SwiftLint with configuration from `.swiftlint.yml`
- **Project Generation**: Run `xcodegen` to regenerate Xcode project from `project.yml`

### Package Management
- Swift Package Manager: Primary dependency management via `Package.swift`
- CocoaPods: Also supported via `SuperwallKit.podspec`
- Dependencies: `Superscript-iOS` at exact version 0.2.8

## Architecture Overview

SuperwallKit is an iOS SDK for remote paywall configuration and A/B testing. The architecture follows a dependency injection pattern centered around `DependencyContainer`.

### Core Components

- **Superwall.swift**: Main SDK entry point and public API
- **DependencyContainer**: Central dependency injection container managing all core services
- **ConfigManager**: Handles remote configuration from Superwall dashboard
- **PaywallManager**: Manages paywall presentation and caching
- **StoreKitManager**: Handles App Store purchases and transactions
- **IdentityManager**: Manages user identity and attributes
- **NetworkManager**: API communication with Superwall backend

### Key Directories

- `Sources/SuperwallKit/`: Main SDK source code
- `Sources/SuperwallKit/Paywall/`: Paywall presentation, caching, and web view handling
- `Sources/SuperwallKit/StoreKit/`: Purchase flow and transaction management
- `Sources/SuperwallKit/Config/`: Remote configuration and feature flags
- `Sources/SuperwallKit/Analytics/`: Event tracking and attribution
- `Sources/SuperwallKit/Dependencies/`: Dependency injection framework
- `Tests/SuperwallKitTests/`: Unit tests with mocks and test utilities

### Data Flow

1. SDK configuration happens through `Superwall.configure()`
2. Remote config is fetched and managed by `ConfigManager`
3. Paywall requests go through `PaywallRequestManager` -> `PaywallManager`
4. Purchases are handled by `StoreKitManager` with automatic retry logic
5. Events are tracked through the analytics system

### Code Conventions

- 2-space indentation (enforced by SwiftLint)
- Prefer `Logger` over `print` statements (enforced by custom lint rule)
- Force unwrapping allowed but discouraged
- Extensive use of protocol factories for dependency injection
- Uses both StoreKit 1 and StoreKit 2 APIs with abstraction layer

### Version Management

- Version is defined in `Sources/SuperwallKit/Misc/Constants.swift` line 21
- Pre-commit hook automatically syncs version to `SuperwallKit.podspec`
- Follows semantic versioning

### Testing

- Mock objects follow naming pattern `*Mock.swift`
- Tests are organized to mirror source structure
- Uses combine publishers for async testing
- Core Data testing uses in-memory store


### Workflows

- When making changes to the SDK, always write a unit test for the new
  functionality.
- Make sure to run the tests, ensuring they pass.
- Finally run swiftlint --fix to ensure the code is formatted correctly.
