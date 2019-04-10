# v4.0
- FirebaseAnalytics is no longer a hard dependency in the DynamicLinks pod. If you were installing Dynamic Links via pod ''Firebase/DynamicLinks'', you should add 'pod 'Firebase/Analytics'' to the Podfile to maintain full Dynamic Links functionality. If you previously have 'pod 'Firebase/Core'' in the Podfile, no change is necessary. (#2738)
- Remove deprecated API in FDLURLComponents. (#2768)

# v3.4.3
- Fixed an issue where matchesshortlinkformat was returning true for certain FDL long links.

# v3.4.2
- Fixes an issue with certain analytics attribution parameters not being recorded on an app install. (#2462)

# v3.4.1
- Return call validation for sysctlbyname. (#2394)

# v3.4.0
- Bug fixes and internal SDK changes. (#2238, #2220)

# v3.3.0
- Introduced a new componentsWithLink:domainURIPrefix: and deprecated the existing componentsWithLink:domain:. (#1962, #2017, #2078, #2097, #2112)

# v3.2.0
- Delete deprecated source files. (#2038)

# v3.1.1
- Use c99 compatible __typeof__() operator. (#1982)

# v3.1.0
- Firebase Dynamic Links is now open source and delivered as a source pod. (#1842)

# v3.0.2
- Bug fixes.

# v3.0.1
- Fixed issue where first app opens were getting double counted when using unique match.

# v2.3.2
- Fixed error when fingerprint match fails for some locales.

# v2.3.1
- Fixed race condition while processing server response(s).

# v2.3.0
- Added new confidence type property. See FIRDLMatchType (values Unique, Default, Weak);
- Updates to self diagnostic output.

# v2.2.0
- Added Other platform fallback link to FDL Builder API;
- Bugfixes and stability improvements.

# v2.1.0
- Added basic self diagnostic to identify Firebase Dynamic Links configuration issues. See method
    [FIRDynamicLinks performDiagnosticsWithCompletion:].
- Fixed returning warning in Builder API, see warnings parameter in
    FIRDynamicLinkShortenerCompletion block.

# v2.0.0
- Change Swift API names to better align with Swift convention.
- Fixes to pending link retrieval process, especially when custom URL schemes are not
  set up properly.

# v1.4.0
- Added Builder API to create and shorten dynamic links in iOS Apps.

# v1.3.5
- Minor update triggered by changes in Firebase Core libraries.

# v1.3.4
- Bug fixes

# v1.3.3
- Improved tracking of social media tag parameters in Dynamic Links

# v1.3.2
- Removes dependency on the Core Motion framework

# v1.3.1
- Adds FIRLogger support (not public-facing)
- Fixes IPv6 compatibilty issues

# v1.3.0
- Removes the SFSafariViewController per Apple's Review Guidelines
- Removes dependency on the Core Location framework

# v1.2.0
- iOS 10 Supoort

# v1.1.1
- Fixes an issue where if resolveLink() API returned a non-JSON object, it
  would cause a crash.

# v1.1.0 (M10)
- Greatly reduced SDK size.

# v1.0.0 (I/O)
- Initial public release.
