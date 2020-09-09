# Firebase Rome

## Context

This page introduces and provides instructions for using Firebase via a
[Rome](https://github.com/CocoaPods/Rome) distribution. Based on
feedback and usage, the Firebase team may decide to make the Rome
support official.

Please [let us know](https://github.com/firebase/firebase-ios-sdk/issues) if you
have suggestions or questions.

## Introduction

Unlike regular CocoaPods, Rome does not touch the Xcode project file. It
installs and builds all of the frameworks and leaves the project integration to
you.

As a result, with Rome, the installed frameworks are all binary whether the
CocoaPod itself was source or binary.

In comparison to Carthage, Rome supports subspecs. Therefore, you can install
exactly the right frameworks customized for your requirements.

## Rome Installation

```bash
$ gem install cocoapods-rome
```

## Firebase Installation

Prefix a Podfile with the following:
```
plugin 'cocoapods-rome',
    dsym: false,
    configuration: 'Release'
```
Then do the following steps:

1. Delete any Firebase pods that you don't need
1. Run `pod install`
1. With the Finder `open Rome`
1. Make sure you have an Xcode project open in Xcode.
1. In Xcode, hit `⌘-1` to open the Project Navigator pane. It will open on
   left side of the Xcode window if it wasn't already open.
1. Drag each framework from the Finder window into Project
   Navigator pane. In the dialog box that appears, make sure the target you
   want the framework to be added to has a checkmark next to it, and that
   you've selected "Copy items if needed".
1. Find the dynamic frameworks: In a shell type:
   `file Rome/*/* | grep universal | grep dynamic`
1. Drag each dynamic framework to the "Embed Frameworks" section on the
   Xcode Build Target's "General" page.
1. If you're using FirebaseInAppMessaging, find the resources needed:
   `ls -ld Pods/*/Resources/*`. More details on this below.
1. Drag all of those resources into the Project Navigator, just
   like the frameworks, again making sure that the target you want to add these
   resources to has a checkmark next to it, and that you've selected "Copy items
   if needed".
1. Add the -ObjC flag to "Other Linker Settings":
  a. In your project settings, open the Settings panel for your target
  b. Go to the Build Settings tab and find the "Other Linker Flags" setting
     in the Linking section.
  c. Double-click the setting, click the '+' button, and add "-ObjC" (without
     quotes)
1. Add Firebase.h and module support:
  a. In your project settings, open the Settings panel for your target
  b. Go to the Build Settings tab and find the "User Header Search Paths"
     setting in the Search Paths section.
  c. Double-click the setting, click the '+' button, and add
     `Pods/Firebase/CoreOnly/Sources`
1. Make sure that the build target(s) includes your project's
   `GoogleService-Info.plist`
   ([how to download config file](https://support.google.com/firebase/answer/7015592)).
1. You're done! Compile your target and start using Firebase.

## Firebase Resource Details
- If you're including a Firebase component that has resources, copy its bundles
    into the Xcode project and make sure they're added to the
    `Copy Bundle Resources` Build Phase :
    - For InAppMessaging:
        - ./Rome/FirebaseInAppMessaging.framework/InAppMessagingDisplayResources.bundle
