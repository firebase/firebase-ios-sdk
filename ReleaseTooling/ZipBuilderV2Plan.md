V2 will add an option to generate a zip distribution of binary frameworks from an arbitrary list
of source and binary CocoaPods.

## Introduction

The current [Zip Builder](https://github.com/firebase/firebase-ios-sdk/tree/main/ZipBuilder)
is Firebase specific. This is a proposal and initial plan to evolve the Zip Builder into a
multi-purpose Apple binary framework creation tool.

It would be useful to have a generic
Zip Builder for other Google SDKs and other open source projects. In addition,
providing a generic Zip Builder would enable Firebase users to generate binary
frameworks for configurations outside the standard zip and Carthage distributions
released in the standard Firebase release process.

With the extra flexibility, the Zip Builder will be useful for both SDK distributors
to package binary distributions and app developers who want a customized binary
distribution that maps exactly to their app's requirements and provides a clean
build time speed up.


## Background

A more flexible Zip Builder would enable the following scenarios:

  * Creating a zip distribution from an arbitrary set of pods
  * Support building with different Xcode versions
  * Build only the subspecs needed for use case
  * [Existing solutions](https://github.com/firebase/firebase-ios-sdk/issues/4284#issuecomment-552677044)
  are intermittently maintained and written in Ruby. A Swift implementation is
  more accessible and maintainable by the Apple community.
  * The Swift implementation will be easier to add Swift Package Manager support for which
  there will likely be a need since Swift Package Manager is even more source-centric than
  CocoaPods.

## Plan

  1. Add `--zipPods {JSON file}` option. The JSON file contains a list of CocoaPods
  along with an optional version specifier. If the version is not specified, a CocoaPods
  install will determine the version - typically the latest, unless another pod requires
  something lower.

  1. Add `--minimumIOSVersion {version}` option. Specify the minimum iOS version to support.
  Default is 8.0.

  1. Add `--archs {archs list}` option. Default is "arm64, arm64e, armv7, i386, x86_64"

Unlike the Firebase zip build which builds a two-level zip file with a configurable set of
installation, when `--zipPods` is specified a single zip file of frameworks will be created.

## Implementation
  * Add check for invalid options (#4411)
  * Build Zip with modern CocoaPods (#4404)
  * Add archs option to ZipBuilder (#4405)
  * Support concurrent Zip Builder runs (#4409)
  * ZipBuilder: -zipPods option (#4422)
  * Rename CocoaPod.swift to FirebasePods.swift (#4423)
  * Simplify Firebase pod naming (#4428)
  * Binary support for Catalyst
  * Migrate to building `.xcframeworks` instead of `.frameworks`
  * Supports building for iOS, macOS, tvOS, macCatalyst, and watchOS
  * Support for building resource bundles and privacy manifests
  * Dynamic Framework support

## Future Directions
  * Support visionOS
  * Swift Package Manager based builds
  * More option customization
  * Tests
