# 9.0.0-beta
- [fixed] Marked `releaseNotes` as `nullable` as they don't always exist (#8602).
- [fixed] **Breaking change:** Fixed an ObjC-to-Swift API conversion error where`checkForUpdate()`
  returned a non-optional type. This change is breaking for Swift users only (#9604).

# 8.3.0-beta
- [changed] Sign out the Tester when the call to fetch releases fails with an unauthorized error (#8270).

# 7.3.0-beta
- [changed] Sign out the Tester when the call to fetch releases fails with an unauthenticated error.
- [fixed] Crash caused by trying to parse response as JSON when response is nil (#6996).

# 0.9.3-beta
- [changed] Updated error log for non-200 API Service calls.

# 0.9.2-beta
- [fixed] Made bug fixes (#6346) available in Zip build and Carthage.

# 0.9.1-beta
- [changed] Updated header comments (#6321).
- [fixed] Bug for customers with restricted API keys unable to fetch releases (#6346).

# 0.9.0-beta
- Initial beta release.
