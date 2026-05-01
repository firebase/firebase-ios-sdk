# 10.27.0
- [fixed] [CocoaPods] missing symbol error for FIRGetLoggerLevel. (#12899)

# 10.25.0
- [changed] Removed usages of user defaults API to eliminate required reason impact.

# 10.19.1
- [fixed] Fix bug in apps using both AppCheck and ARCore where AppCheck
  unnecessarily tries to create tokens for the ARCore SDK. This results in
  noisy logs containing harmless attestation errors.

# 10.18.0
- [changed] Extracted core `FirebaseAppCheck` functionality into a new
  [`AppCheckCore`](https://github.com/google/app-check) dependency. (#12067)

# 10.17.0
- [fixed] Added invalid key error handling in App Attest key attestation. (#11986)
- [fixed] Replaced semantic imports (`@import FirebaseAppCheckInterop`) with umbrella header imports
  (`#import <FirebaseAppCheckInterop/FirebaseAppCheckInterop.h>`) for ObjC++ compatibility (#11916).

# 10.9.0
- [feature] Added `limitedUseToken(completion:)` for obtaining limited-use tokens for
  protecting non-Firebase backends. (#11086)

# 9.5.0
- [added] DeviceCheck and App Attest providers are supported by watchOS 9.0+. (#10094, #10098)
- [added] App Attest provider availability updated to support tvOS 15.0+. (#10093)

# 9.0.0
- [added] **Breaking change:** `FirebaseAppCheck` has exited beta and is now
  generally available for use.

# 8.12.0
- [fixed] Build failures with Swift Package Manager for watchOS. (#9191)

# 8.9.0
- [fixed] Improved error handling logic by minimizing amount of requests that are unlikely to succeed. (#8798)

# 8.8.0
- [added] Add support for bundle ID-based API Key Restrictions (#8678)

# 8.6.0
- [changed] Documented unsupported platforms (#8493).

# 8.5.0
- [changed] App Check SDK available for all supported platforms/OS versions, but App Attest and
DeviceCheck providers availability changed to match underlying platform API availability. (#8388)

# 8.4.0
- [fixed] Fixed build issues introduced in Xcode 13 beta 3. (#8401)
- [fixed] Bump Promises dependency. (#8365)

# 8.3.0
- [added] Token API for 3P use. (#8266)

# 8.2.0
- [added] Apple's App Attest attestation provider support. (#8133)
- [changed] Token auto-refresh optimizations. (#8232)

# 8.0.0
- [added] Firebase abuse reduction support SDK. (#7928, #7937, #7948)
