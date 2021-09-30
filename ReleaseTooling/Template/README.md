# Firebase iOS SDKs

This directory contains the full Firebase iOS distribution, packaged as
static frameworks and xcframeworks that can be integrated into your app.

# Integration Instructions

Each Firebase component requires several frameworks in order to function
properly. Each section below lists the frameworks you'll need to include
in your project in order to use that Firebase SDK in your application.

Xcode 12.2 or newer is required.

To integrate a Firebase SDK with your app:

1. Find the desired SDK in the list below.
2. Make sure you have an Xcode project open in Xcode.
3. In Xcode, hit `⌘-1` to open the Project Navigator pane. It will open on
   left side of the Xcode window if it wasn't already open.
4. Remove any existing Firebase frameworks from your project.
5. Drag each framework from the "FirebaseAnalytics" directory into the Project
   Navigator pane. In the dialog box that appears, make sure the target you
   want the framework to be added to has a checkmark next to it, and that
   you've selected "Copy items if needed". If you want to include
   community-based Catalyst support, only drag the xcframeworks and skip the
   plain frameworks.
6. Drag each framework from the directory named after the SDK into the Project
   Navigator pane. Note that there may be no additional frameworks, in which
   case this directory will be empty. For instance, if you want the Database
   SDK, look in the Database folder for the required frameworks. In the dialog
   box that appears, make sure the target you want this framework to be added to
   has a checkmark next to it, and that you've selected "Copy items if needed."

   *Do not add the Firebase frameworks to the "Embed Frameworks" Xcode build
   phase. The Firebase frameworks are not embedded dynamic frameworks, but are
   [static frameworks](https://www.raywenderlich.com/65964/create-a-framework-for-ios)
   which cannot be embedded into your application's bundle.*

7. If the SDK has resources, go into the Resources folders, which will be in
   the SDK folder. Drag all of those resources into the Project Navigator, just
   like the frameworks, again making sure that the target you want to add these
   resources to has a checkmark next to it, and that you've selected "Copy items
   if needed".
8. Add the -ObjC flag to "Other Linker Settings":
  a. In your project settings, open the Settings panel for your target
  b. Go to the Build Settings tab and find the "Other Linker Flags" setting
     in the Linking section.
  c. Double-click the setting, click the '+' button, and add "-ObjC" (without
     quotes)
9. Drag the `Firebase.h` header in this directory into your project. This will
   allow you to `#import "Firebase.h"` and start using any Firebase SDK that you
   have.
10. If you're using Swift or want to use modules from Objective C, drag
   `module.modulemap` into your project and update the
   "User Header Search Paths" in your project's Build Settings to include the
   directory that contains the added module map.
11. You're done! Compile your target and start using Firebase.

If you want to add another SDK, repeat the steps above with the frameworks for
the new SDK. You only need to add each framework once, so if you've already
added a framework for one SDK, you don't need to add it again. Note that some
frameworks are required by multiple SDKs, and so appear in multiple folders.

The Firebase frameworks list the system libraries and frameworks they depend on
in their modulemaps. If you have disabled the "Link Frameworks Automatically"
option in your Xcode project/workspace, you will need to add the system
frameworks and libraries listed in each Firebase framework's
<Name>.framework/Modules/module.modulemap file to your target's or targets'
"Link Binary With Libraries" build phase.  Specifically, you may see the error
`ld: warning: Could not find or use auto-linked framework...` which is an
indicator that not all system libraries are being brought into your build
automatically.

"(~> X)" below means that the SDK requires all of the frameworks from X. You
should make sure to include all of the frameworks from X when including the SDK.

__INTEGRATION__
# Samples

You can get samples for Firebase from https://github.com/firebase/quickstart-ios:

    git clone https://github.com/firebase/quickstart-ios

Note that several of the samples depend on SDKs that are not included with
this archive; for example, FirebaseUI. For the samples that depend on SDKs not
included in this archive, you'll need to use CocoaPods or use the
[ZipBuilder](https://github.com/firebase/firebase-ios-sdk/tree/master/ReleaseTooling)
to create your own custom binary frameworks.

# Versions

The frameworks in this directory map to these versions of the Firebase SDKs in
CocoaPods.

__VERSIONS__
