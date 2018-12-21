# Symbol Collision Tests

## Introduction

This directory provides a project that is used to test a set of CocoaPods for symbol
collisions daily.  It's controlled by the cron functionality in
[.travis.ml](../.travis.yml).

## Run Locally

* `git clone git@github.com:firebase/firebase-ios-sdk.git`
* `cd firebase-ios-sdk/SymbolCollisionTest`
* Optionally make any changes to the Podfile
* `pod install`
* `open SymbolCollisionTest.xcworkspace`
* Build

## Contributing

If you'd like to add a CocoaPod to the tests, add it to the
[Podfile](Podfile), test that it builds locally and then send a PR.

## Future

Currently the tests primarily test static libraries and static frameworks.
`use_frameworks!` and
[`use_module_headers!`](http://blog.cocoapods.org/CocoaPods-1.5.0/) can be
added for better dynamic library and Swift pod testing.

Currently, this is testing released CocoaPods. It could be changed to support
pre-releases by changing the Podfile to point to source pods and/or setting up
a public staging Specs repo and adding a `source` in the Podfile.
