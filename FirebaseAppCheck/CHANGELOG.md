# v9.0.0
- [added] **Breaking change:** `FirebaseAppCheck` has exited beta and is now
  generally available for use.

# v8.12.0
- [fixed] Build failures with Swift Package Manager for watchOS. (#9191)

# v8.9.0
- [fixed] Improved error handling logic by minimizing amount of requests that are unlikely to succeed. (#8798)

# v8.8.0
- [added] Add support for bundle ID-based API Key Restrictions (#8678)

# v8.6.0
- [changed] Documented unsupported platforms (#8493).

# v8.5.0
- [changed] App Check SDK available for all supported platforms/OS versions, but App Attest and
DeviceCheck providers availability changed to match underlying platfrom API availability. (#8388)
# v8.4.0
- [fixed] Fixed build issues introduced in Xcode 13 beta 3. (#8401)
- [fixed] Bump Promises dependency. (#8365)
# v8.3.0
- [added] Token API for 3P use. (#8266)
# v8.2.0
- [added] Apple's App Attest attestation provider support. (#8133)
- [changed] Token auto-refresh optimizations. (#8232)
# v8.0.0
- [added] Firebase abuse reduction support SDK. (#7928, #7937, #7948)
