# Contributing to SuperwallKit

We want to make contributing to this project as easy and transparent as
possible, and actively welcome your pull requests. If you run into problems,
please open an issue on GitHub.

## Pull Requests

1. Fork the repo and create your branch from `develop`.
2. Run the setup script `./scripts/setup.sh`
3. If you've added code that should be tested, add tests.
4. If you've changed APIs, update the documentation.
5. Ensure the test suite passes.
6. Make sure your code lints (see below).
7. Tag @yusuftor, @jakemor, and @anglinb in the pull request.
8. Add an entry to the [CHANGELOG.md](../CHANGELOG.md) for any breaking changes, enhancements, or bug fixes.
9. After the PR is merged, delete the branch.

## Coding Style

### Xcode Preferences
In Xcode, you'll need to set your indentation spacing to 2 spaces. You can do that by going to **Xcode ▸ Preferences...**, then choose the **Text Editing** tab. Inside the **Display** tab, set **Indent wrapped lines by:** to **2 spaces**:

<p align="center">
  <img width="830" alt="Indent wrapped lines by 2 spaces" src="https://user-images.githubusercontent.com/3296904/159707444-c3524fef-b31f-4495-b8ca-2ecd8fc7f698.png">
</p>

In the **Editing** tab, select **Automatically trim trailing whitespace**:

<p align="center">
  <img width="830" alt="Automatically trim trailing whitespace" src="https://user-images.githubusercontent.com/3296904/159707570-5e38f179-7568-4a49-89b5-25158686e439.png">
</p>

In the **Indentation** tab, set **Tab Width** and **Indent Width** to **2 spaces**:

<p align="center">
  <img width="830" alt="2 space indent and tab width" src="https://user-images.githubusercontent.com/3296904/159707661-46e1eed0-d90e-4912-af8c-28e987d5ab60.png">
</p>

### SwiftLint
To maintain readability and achieve code consistency, we follow the [Raywenderlich Swift Style Guide](https://github.com/raywenderlich/swift-style-guide).
We use [SwiftLint](https://github.com/realm/SwiftLint) to check for style errors.

To do this locally, you can run `swiftlint` from the root folder.

Unfortunately, SwiftLint can't be run on build in Xcode for Swift Packages, so we use GitHub actions instead.
Every time a commit that has a change in swift code is pushed to GitHub, a GitHub Action automatically runs SwiftLint. Warnings and errors will show up as Annotations under the GitHub Action telling you what needs to change. Please fix these linting issues before creating a pull request.

### Documentation
Public classes and methods must contain detailed documentation.

All documentation is compiled using [DocC](https://github.com/apple/swift-docc) and hosted on [GitHub-Pages](https://pages.github.com). This is then accessible via our [iOS SDK documentation](https://sdk.superwall.me/documentation/SuperwallKit/). You can also view this in Xcode by selecting **Product ▸ Build Documentation**.

## Editing the code

Open the workspace from: `.swiftpm/xcode/package.xcworkspace`.

If you are editing one the example apps, open the example app's `xcodeproj` directly. The advantage of this is that you can see linting issues on build.

## Git Workflow

We have two branches: `master` and `develop`.

All pull requests are set to merge into `develop`, with the exception of a hotfix on `master`.

Name your branch `feature/<feature name>` for consistency.

When we're ready to cut a new release, we update the `sdkVersion` in [Constants.swift](/Sources/Superwall/Misc/Constants.swift) and merge `develop` into `master`. This runs some GitHub actions to tag the release, build the docs, and push to cocoapods.

## Testing

If you add new code, please make sure it gets tested! When fixing bugs, try to reproduce the bug in a unit test and then fix the test. This makes sure we never regress that issue again.
Before creating a pull request, run all unit tests by pressing **Cmd + U**. Make sure they all pass and fix any broken tests.
We also have a GitHub Action that runs the tests on push.

## Issues

We use GitHub issues to track public bugs. Please ensure your description is clear and has sufficient instructions to be able to reproduce the issue.

## License

By contributing to `SuperwallKit`, you agree that your contributions will be licensed under the LICENSE file in the root directory of this source tree.
