# Firebase Swift Modernization Dashboard

This dashboard summarizes the status of Firebase's [2022 Swift Modernization Project](ROADMAP.md).
Please upvote or create a [feature request](https://github.com/firebase/firebase-ios-sdk/issues)
to help prioritize any particular cell(s).

This dashboard is intended to track an initial full Swift review of Firebase along with addressing low-hanging fruit. We would expect it to identify additional follow up
tasks for additional Swift improvements.

|                       | An    | ApC   | ApD   | Aut   | Cor   | Crs   | DB    | DL    | Fst   | Fn    | IAM   | Ins   | Msg   | MLM   | Prf   | RC    | Str   |
|   :---                | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **Swift Library**     | ✅    | ❌    |❌     | ❌   | n/a  | ❌    |  ✅   | ❌   |  ✅   | ✅    |  ✅   | ❌   | ❌   | ✅    | ❌    |  ✅  | ✅   |
| **Single Module**     |   ❌  | ✅    |✅     | ✅   | ✅   |  ✅   |  ❌  |  ✅   |  ❌   | ✅    |  ❌  | ✅    |  ✅  | ✅    |  ✅   | ❌   | ✅  |
| **API Tests**         |  ✅   |  ✅   |❌     | ✅   | ✅   | ❌    |  ✅   | ❌   | 1     |  ✅   | 1     | ✅    | ✅   | 1     | ❌    |  ✅  | ✅  |
| **async/await**       |  ✅   |  ✅   | ✅    | ✅   |  ✅  | ✅    |  ✅   | ❌   |  ✅   |  ✅   | ✅   | ✅    | ✅   | ❌    | ✅    |  ✅  | ✅   |
| **Swift Errors**      |  ✅   |  ✅   | ✅    | 2    | ✅   | 5      | ❌    | ❌   |  ✅   | ❌   | ❌    |  ✅   |  ✅  | ✅    | ✅    |   ✅ | 3    |
| **Codable**           |  n/a  | n/a   | n/a    | n/a  | n/a   | n/a   |  ✅   | n/a   |  ✅   | ✅   | n/a   | n/a   | n/a   | n/a   | n/a   |   ✅  | n/a   |
| **SwiftUI Lifecycle** |  ❌   | n/a   | n/a   | ❌   | n/a   | n/a   | n/a   | ❌    | n/a   | n/a   | n/a   | n/a   | ❌    | n/a   | ❌    | n/a   | n/a   |
| **SwiftUI Interop**   |   ✅  | n/a   | ❌    | ❌   | n/a   | ❌    | ❌    | n/a   | ✅   | n/a   | ✅    | n/a   | n/a   | n/a   | ❌    | n/a   | n/a   |
| **Property Wrappers** |  n/a  | n/a   | n/a   | ❌    | n/a   | n/a   | ❌    | n/a   | 4     | n/a   | n/a   | n/a   | n/a   | n/a   | n/a   | ❌   | n/a   |
| **Swift Doc Scrub**   |   ✅  |  ✅   | ✅    | ✅   | ✅   | ✅    |  ✅   |  ✅   |  ✅  |  ✅   |  ✅    | ✅  |  ✅   | ✅   |  ✅   |  ✅   |  ✅|

### Other Projects
- Tooling to surface full list of automatically generated Swift API from Objective-C and validate.
- Improve singleton naming scheme. Move singletons into a Firebase namespace, like `Firebase.auth()`, `Firebase.storage()`, etc.
- Swift Generics. Update APIs that are using weakly typed information to use proper generics.

## Notes
1. Tests exist. Coverage to be confirmed.
2. `NS_ERROR_ENUM` used but a larger audit is still needed for more localized errors.
3. Still needs to unify Objective-C and Swift errors.
4. One property wrapper added in [#8614](https://github.com/firebase/firebase-ios-sdk/pull/8614). More to go.
5. `record(Error)` API should be expanded to collect Swift Errors as well as NSErrors.

## Rows (Swift Capabilities)
* **Swift Library**: SDK includes public APIs written in Swift, either in the main product library or a Swift-specific extension.
* **Single Module**: Public API surface in a single module.
* **API Tests**: Tests exist for all Swift APIs. Integration tests are preferred, but compile-only tests are acceptable.
* **async/await**:API tests include tests for all auto-generated async/await APIs. Implementations are added for
asynchronous APIs that don't have auto-generated counterparts like
[these](https://github.com/firebase/firebase-ios-sdk/blob/master/FirebaseStorage/Tests/Integration/StorageAsyncAwait.swift)
for Storage.
* **Swift Errors**: Swift Error Codes are available instead of NSErrors.
* **Codable**: Codable is implemented where appropriate.
* **SwiftUI Lifecycle**: Dependencies on the AppDelegate Lifecycle are migrated to the Multicast AppDelegate.
* **SwiftUI Interop**: Update APIs that include UIViewControllers (or implementations that depend on them) to work with SwiftUI. This will overlap with
Property Wrappers and likely the SwiftUI lifecycle bits, but an audit and improvements could likely be made. The existing FIAM and Analytics View modifier
APIs would fit into this category.
* **Property Wrappers**: Property wrappers are used to improve the API.
* **Swift Doc Scrub**: Review and update to change Objective-C types and call examples to Swift. In addition to updating the documentation content, we
should also investigate using DocC to format the docs.

## Columns (Firebase Products)
* An - Analytics
* ApC - App Check
* ApD - App Distribution
* Aut - Auth
* Cor - Core
* Crs - Crashlytics
* DB - Real-time Database
* DL - Dynamic Links
* Fst - Firestore
* Fn - Functions
* IAM - In App Messaging
* Ins - Installations
* Msg - Messaging
* MLM - MLModel Downloader
* Prf - Performance
* RC - Remote Config
* Str - Storage
