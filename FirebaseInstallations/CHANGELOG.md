# v8.4.0 -- M100
- [fixed] Bump Promises dependency. (#8365)

# v7.0.0 -- M82
- [changed] The global variable `FIRInstallationsVersionStr` is deleted.
  `FirebaseVersion()` or `FIRFirebaseVersion()` should be used instead.
- [changed] Throw an exception if `FIROptions.projectID` is missing or
  `FIROptions.APIKey` has incorrect format to catch critical configuration
  issues earlier. (#4692)
- [changed] Removed the `FIR` prefix from `FIRInstallationIDDidChange` and renamed
  `kFIRInstallationIDDidChangeNotificationAppNameKey` to `InstallationIDDidChangeAppNameKey`
  in Swift.
- [changed] API docs updated to use term "installation auth token" consistently. (#6014)

# v1.7.1 -- M81
- [changed] Additional `FIRInstallationsItem` validation to catch potential storage issues. (#6570)

# v1.7.0 -- M78
- [changed] Use ephemeral `NSURLSession` to prevent caching of request/response. (#6226)
- [changed] Backoff added for some error to prevent unnecessary API requests. (#6232)

# v1.5.0 -- M75
- [changed] Functionally neutral source reorganization. (#5832)

# v1.3.0 -- M72

- [changed] Mac OS Keychain storage changes: use a unique (per app) Keychain Service name to isolate Keychain items for different Mac OS applications.
  NOTE: Installation Identifiers created by previous versions will be reset on Mac OS which can affect e.g. A/B Testing variants or debug device targeting for Firebase Messaging.
  iOS, tvOS and watchOS Installation Identifiers will not be affected. (#5603)
- [changed] More readable server error console messages. (#5654)
- [changed] Auth Token auto fetch disabled. (#5656)

# v1.2.0 -- M69

- [changed] Keychain key-value storage refactored to `GoogleUtilities`. (#5329)

# v1.1.1 -- M67

- [fixed] Accessing `GULHeartbeatDateStorage` moved out of main thread. (#5098)

# v1.1.0 -- M62.1

- [changed] Throw an exception when there are missing required `FirebaseOptions` parameters (`APIKey`, `googleAppID`, and `projectID`). Please make sure your `GoogleServices-Info.plist` (or `FirebaseOptions` if you configure Firebase in code) is up to date. The file and settings can be downloaded from the [Firebase Console](https://console.firebase.google.com/).  (#4683)

# v1.0.0 -- M62

- [added] The Firebase Installations Service is an infrastructure service for Firebase services that creates unique identifiers and authentication tokens for Firebase clients (called "Firebase Installations") enabling Firebase Targeting, i.e. interoperation between Firebase services.
- [added] The Firebase Installations SDK introduces the Firebase Installations API. Developers that use API-restrictions for their API-Key may experience blocked requests (https://stackoverflow.com/questions/58495985/). This problem can be mitigated by following the instructions found [here](API_KEY_RESTRICTIONS.md).
