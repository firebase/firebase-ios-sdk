# Firebase Swift Modernization Dashboard

This dashboard summarizes the status of Firebase's [2022 Swift Modernization Project](ROADMAP.md).
Please upvote or create a [feature request](https://github.com/firebase/firebase-ios-sdk/issues)
to help prioritize any particular cell(s).

This dashboard is intended to track an initial full Swift review of Firebase along with addressing low-hanging fruit. We would expect it to identify additional follow up
tasks for additional Swift improvements.

|                       | AB  | An     | ApC    | ApD    | Aut    | Cor    | Crs    | DB     | Fst    | Fn     | IAM    | Ins    | Msg    | MLM    | Prf    | RC     |    Str |
|   :---                | :--- | :----: | :----: | :----: | :----: | :----: | :----: | :----: | :----: | :----: | :----: | :----: | :----: | :----: | :----: | :----: | :----: |
| **Swift Library**     | ❌   |   ✔   | ❌     |❌     | ❌     | ❌     | ❌      |  ✔     |  ✔    | 1      |  ✔     | ❌    | ❌     | ✔      | ❌     | ❌    | ✔     |
| **API Tests**         | ❌   |  ❌    |  ✔    |❌     | ❌     | ✔       | ❌     | 3      | 2     |  ✔     | 2      | ✔      | ❌     | 2      | ❌    |  ✔     | ✔    |
| **async/await**       | ❌   |  n/a   |  ✔    |❌     | ❌     |  ✔      | ❌     | 3     | ❌     |  ✔     | ❌     | ❌    | ❌     | ❌    | ❌     |  ✔    | ✔    |
| **Swift Errors**      |  ❌  |  ❌    | ❌    |❌     | 4      | ❌     | ❌     | ❌     | ❌    | ❌     | ❌     | ❌    | ❌     | ✔      | ❌     | ❌   | 5   |
| **Codable**           | n/a  | n/a     | n/a   |n/a    | n/a     | n/a    |n/a     |  ✔     |  ✔     | 1      | n/a     | n/a   | ❌     | n/a    | n/a    |  ❌  |n/a   |
| **SwiftUI Lifecycle** | n/a  |  ❌    | n/a    |❌     | ❌     | n/a    |n/a     | n/a    | n/a    | n/a     | n/a    | n/a   | ❌     | n/a    | n/a    | n/a   |n/a  |
| **SwiftUI Interop**   | ❌   |  ✔     | ❌     |❌    | ❌     | ❌     |❌      | ❌     | ❌    | ❌     | ✔      | ❌    | ❌     | ❌    | ❌     | ❌    |n/a  |
| **Property Wrappers** |  ❌  |  ❌    | ❌    |❌     | ❌     | ❌     | ❌     | ❌     | 6     | ❌     | ❌     | ❌    | ❌     | ❌    | ❌     | ❌   |❌    |
| **Swift Doc Scrub**   |  ❌  |  ❌    | ❌    |❌     | ❌     | ❌     | ❌     | ❌     |  ❌   | ❌     | ❌     | ❌    | ❌     | ❌    | ❌     | ❌   |❌    |

### Other Projects
- Tooling to surface full list of automatically generated Swift API from Objective C and validate.
- Improve singleton naming scheme. Move singletons into a Firebase namespace, like `Firebase.auth()`, `Firebase.storage()`, etc.
- Swift Generics. Update APIs that are using weakly typed information to use proper generics.

## Notes
1. In progress at [#8854](https://github.com/firebase/firebase-ios-sdk/pull/8854)
2. Tests exist. Coverage to be confirmed.
3. Mostly done. Need to review open questions in the RTDB tab [here](https://docs.google.com/spreadsheets/d/1HS4iJBtTHA9E01VrcsiVn_GVOa7KOCcn5LNw3sWlGoU/edit#gid=75586175).
4. Feature Request at [#7723](https://github.com/firebase/firebase-ios-sdk/pull/7723) and PR at [#9000](https://github.com/firebase/firebase-ios-sdk/pull/9000)
5. Started at [#9007](https://github.com/firebase/firebase-ios-sdk/pull/9007) and continued with breaking changes in https://github.com/firebase/firebase-ios-sdk/tree/storage-v9.
6. One property wrapper added in [#8614](https://github.com/firebase/firebase-ios-sdk/pull/8614). More to go.

## Rows (Swift Capabilities)
* **Swift Library**: A Swift implemented extension library exists. It is deployed as Firebase{Product}Swift CocoaPod and as a Swift Package Manager product.
* **API Tests**: Tests exist for all Swift APIs. Integration tests are preferred, but compile-only tests are acceptable.
* **async/await**:API tests include tests for all auto-generated async/await APIs. Implementations are added for
asynchronous APIs that don't have auto-generated counterparts like
[these](https://github.com/firebase/firebase-ios-sdk/blob/master/FirebaseStorageSwift/Tests/Integration/StorageAsyncAwait.swift)
for Storage.
* **Swift Errors**: Swift Error Codes are available instead of NSErrors.
* **Codable**: Codable is implemented where appropriate.
* **SwiftUI Lifecycle**: Dependencies on the AppDelegate Lifecycle are migrated to the Multicast AppDelegate.
* **SwiftUI Interop**: Update APIs that include UIViewControllers (or implementations that depend on them) to work with SwiftUI. This will overlap with
Property Wrappers and likely the SwiftUI lifecycle bits, but an audit and improvements could likely be made. The existing FIAM and Analytics View modifier
APIs would fit into this category.
* **Property Wrappers**: Property wrappers are used to improve the API.
* **Swift Doc Scrub**: Review and update to change Objective C types and call examples to Swift. In addition to updating the documentation content, we
should also investigate using DocC to format the docs.

## Columns (Firebase Products)
* AB - AB Testing
* An - Analytics
* ApC - App Check
* ApD - App Distribution
* Aut - Auth
* Cor - Core
* Crs - Crashlytics
* DB - Real-time Database
* Fst - Firestore
* Fn - Functions
* IAM - In App Messaging
* Ins - Installations
* Msg - Messaging
* MLM - MLModel Downloader
* Prf - Performance
* RC - Remote Config
* Str - Storage
