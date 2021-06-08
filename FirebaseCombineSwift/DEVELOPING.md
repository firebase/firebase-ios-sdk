# Developing

This is a quick overview to help you get started contributing to Firebase Combine.

## Prerequisites

* Xcode 12.x (or later)
* CocoaPods 1.10.x (or later)
* [CocoaPods Generate](https://github.com/square/cocoapods-generate)

## Setting up your development environment

* Check out firebase-ios-sdk
* Install utilities

```bash
$ ./scripts/setup_check.sh
$ ./scripts/setup_bundler.sh
```

## Generating the development project

For developing _Firebase Combine_, you'll need a development project that imports the relevant pods.

Run the following command to generate and open the development project:

```bash
$ pod gen FirebaseCombineSwift.podspec --local-sources=./ --auto-open --platforms=ios
```

## Checking in code

Before checking in your code, make sure to check your code against the coding styleguide by running the following command:

```bash
$ ./scripts/check.sh --allow-dirty
```