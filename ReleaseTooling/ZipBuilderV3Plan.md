V3 will fully separate the Firebase zip build process from building binary frameworks
from CocoaPods. The binary building tool will be Firebase-agnostic, with the Firebase
packaging built on top of it. This will allow more flexibility for end-users as well as
other SDK distributors to use the binary building tool.

## Introduction

The current [Zip Builder](https://github.com/firebase/firebase-ios-sdk/tree/main/ZipBuilder)
is Firebase specific. This is a proposal and initial plan to evolve the Zip Builder into a
multi-purpose Apple binary framework creation tool.

It would be useful to have a generic Zip Builder for other Google SDKs and other open
source projects. In addition, providing a generic Zip Builder would enable Firebase users
to generate binary frameworks for configurations outside the standard zip and Carthage
distributions released in the standard Firebase release process.

With the extra flexibility, the Zip Builder will be useful for both SDK distributors
to package binary distributions and app developers who want a customized binary
distribution that maps exactly to their app's requirements and provides a clean
build time speed up.

## Background

A more flexible Zip Builder would enable the following scenarios:

  * Support different building different sets of platform slices
  * Build only the subspecs needed for use case (for CocoaPods)
  * Use Swift Package Manager instead of CocoaPods if desired
  * Developers or other library authors  could use the tool to generate binaries without
    having to interact with Firebase specific tools

## Plan

  * Separate binary building tool into a separate target
  * Scrub any Firebase specific functionality from the binary building tool
  * Re-structure the Firebase tool to depend on the new binary building tool
  * Evaluate moving the binary building tool to a separate repo

## Implementation

TBC once PRs are complete.

## Future Directions

  * Binary support for Catalyst
  * Other Apple platforms besides iOS
  * Use Swift Package Manager instead of CocoaPods
  * More option customization
  * Add tests to the tooling for easier validation
