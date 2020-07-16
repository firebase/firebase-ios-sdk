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