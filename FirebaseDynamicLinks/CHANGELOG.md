# 11.8.0
- [deprecated] The `FirebaseDynamicLinks` CocoaPod is deprecated. For information about timelines and alternatives, see the [Dynamic Links deprecation FAQ](https://firebase.google.com/support/dynamic-links-faq).

# 10.27.0
- [deprecated] Dynamic Links is deprecated. For information about timelines and alternatives, see the [Dynamic Links deprecation FAQ](https://firebase.google.com/support/dynamic-links-faq)

# 10.3.0
- [fixed] Fixes issue where `utmParametersDictionary` / `minimumAppVersion` were not provided and their value were set to `[NSNull null]` instead of `nil`.

# 10.2.0
- [fixed] Fixes utm parameters not being returned to dynamic link when using universal links (#10341)

# 10.0.0
- [removed] Removed bare initializer from `DynamicLink`. (#10000)
- [fixed] Added app.google (1p domain) support in FDL SDK which was missing.

# 9.0.0
- [fixed] Fixed async/await crash when retrieving a dynamic link from a universal link fails. (#9612)

# 8.15.0
- [fixed] Fixed Custom domain long url validation logic. (#6978)

# 8.9.0
- [fixed] Fixed Shortlink regression involving underscores and dashes introduced in 8.8.0. (#8786)
- [fixed] Reduce memory stress on `WebKit` API. (#8847)
- [fixed] Fixed regression introduced in 8.8.0 that failed to accept link query params after the
  FDL domain prefix. It caused the Dynamic Links Quick Start to fail. (#8866)

# 8.8.0
- [fixed] Firebase dynamic links with custom domain will only work if the custom domain has a trailing '/'. (#7087)
- [fixed] Fix device-only build warning for unused `processIsTranslated` function. (#8694)

# 8.7.0
- [added] Refactoring and adding helper class. (#8432)

# 8.6.0
- [changed] Replaced conditionally-compiled APIs with `API_UNAVAILABLE` annotations on unsupported platforms (#8467).

# 8.4.0
- [fixed] Fixed build issues introduced in Xcode 13 beta 3. (#8401)
- [fixed] Fixed build failures for extension targets. (#6548)

# 8.2.0
- [fixed] Fixed analyze issue introduced in Xcode 12.5. (#8208)

# 8.0.0
- [fixed] Fixed crashes on simulators targeting below iOS14 on Apple Silicon. (#7989)

# 7.7.0
- [added] Added `utmParametersDictionary` property to `DynamicLink`. (#6730)

# 7.6.0
- [fixed] Fixed build warnings introduced with Xcode 12.5. (#7434)

# 7.3.1
- [fixed] New callback added in 7.3.0 should be on the main thread. (#7159)

# 7.3.0
- [added] Manually created dynamic links should be subject to allowed/blocked check (#5853)

# 4.3.1
- [changed] Client id usage in api call and respective checks in the code.
- [fixed] Fix attempts to connect to invalid ipv6 domain by updating ipv4 and ipv6 to use a single, valid endpoint (#5032)

# 4.3.0
- [changed] Functionally neutral public header refactor to enable Swift Package
  Manager support.

# 4.2.1
- [fixed]Check for Pending Dynamic link guard check logic

# 4.2.0
- [fixed] Fixed crashes that occur when a dynamic link is opened for the second time while an app is in the foreground (#5880)
- [Added] Plist property `FirebaseDeepLinkPasteboardRetrievalEnabled` to enable/disable fetching dynamic links from Pasteboard.
- [fixed] Reduce frequency of iOS14 pasteboard notifications by only reading from it when it contains URL(s). (#5905)
- [changed] Functionally neutral updated import references for dependencies. (#5824)

Refer to the [README.md](https://github.com/firebase/firebase-ios-sdk/blob/main/FirebaseDynamicLinks/README.md) for more details about this release.

# 4.1.0
- [fixed] Fixing unwanted pending dynamic links checks on subsequent app restarts. (#5665)

# 4.0.8
- [fixed] Fix Catalyst build - removed deprecated unused Apple framework dependencies. (#5139)

# 4.0.7
- [fixed] Use module import syntax for headers from other SDKs. (#4824)

# 4.0.6
- [fixed] Fix component startup time. (#4137)
- [fixed] Fix crash due to object deallocation on app launch. (#4308)

# 4.0.5
- [fixed] Removed references to UIWebViewDelegate to comply with App Store Submission warning. (#3722)

# 4.0.4
- [fixed] Removed references to UIWebView to comply with App Store Submission warning. (#3722)

# 4.0.3
- [added] Added support for custom domains for internal Google apps. (#3540)

# 4.0.2
- [changed] Updated to maintain compatibility with Firebase Core in 6.6.0.

# 4.0.1
- [changed] Removed deprecated internal log method. (#3333)

# 4.0
- [feature] FirebaseAnalytics is no longer a hard dependency in the DynamicLinks pod. If you were installing Dynamic Links via pod ''Firebase/DynamicLinks'', you should add 'pod 'Firebase/Analytics'' to the Podfile to maintain full Dynamic Links functionality. If you previously have 'pod 'Firebase/Core'' in the Podfile, no change is necessary. (#2738)
- [removed] Remove deprecated API in FDLURLComponents. (#2768)

# 3.4.3
- [fixed] Fixed an issue where matchesshortlinkformat was returning true for certain FDL long links.

# 3.4.2
- [fixed] Fixes an issue with certain analytics attribution parameters not being recorded on an app install. (#2462)

# 3.4.1
- [changed] Return call validation for sysctlbyname. (#2394)

# 3.4.0
- [changed] Bug fixes and internal SDK changes. (#2238, #2220)

# 3.3.0
- [added] Introduced a new `componentsWithLink:domainURIPrefix:` and deprecated the existing `componentsWithLink:domain:`. (#1962, #2017, #2078, #2097, #2112)

# 3.2.0
- [changed] Delete deprecated source files. (#2038)

# 3.1.1
- [changed] Use c99 compatible __typeof__() operator. (#1982)

# 3.1.0
- [feature] Firebase Dynamic Links is now open source and delivered as a source pod. (#1842)

# 3.0.2
- [changed] Bug fixes.

# 3.0.1
- [fixed] Fixed issue where first app opens were getting double counted when using unique match.

# 2.3.2
- [fixed] Fixed error when fingerprint match fails for some locales.

# 2.3.1
- [fixed] Fixed race condition while processing server response(s).

# 2.3.0
- [added] Added new confidence type property. See FIRDLMatchType (values Unique, Default, Weak);
- [changed] Updates to self diagnostic output.

# 2.2.0
- [added] Added Other platform fallback link to FDL Builder API;

# 2.1.0
- [added] Added basic self diagnostic to identify Firebase Dynamic Links configuration issues. See method
  [FIRDynamicLinks performDiagnosticsWithCompletion:].
- [fixed] Fixed returning warning in Builder API, see warnings parameter in
  FIRDynamicLinkShortenerCompletion block.

# 2.0.0
- [fixed] Change Swift API names to better align with Swift convention.
- [fixed] Fixes to pending link retrieval process, especially when custom URL schemes are not
  set up properly.

# 1.4.0
- [added] Added Builder API to create and shorten dynamic links in iOS Apps.

# 1.3.5
- [changed] Minor update triggered by changes in Firebase Core libraries.

# 1.3.4
- [changed] Bug fixes

# 1.3.3
- [changed] Improved tracking of social media tag parameters in Dynamic Links

# 1.3.2
- [changed] Removes dependency on the Core Motion framework

# 1.3.1
- [added] Adds FIRLogger support (not public-facing)
- [fixed] Fixes IPv6 compatibility issues

# 1.3.0
- [changed] Removes the SFSafariViewController per Apple's Review Guidelines
- [changed] Removes dependency on the Core Location framework

# 1.2.0
- [added] iOS 10 Support

# 1.1.1
- [fixed] Fixes an issue where if resolveLink() API returned a non-JSON object, it
  would cause a crash.

# 1.1.0
- [fixed] Greatly reduced SDK size.

# 1.0.0
- Initial public release.
