# Firebase Swift Modernization Dashboard

This dashboard summarizes the status of Firebase's [2022 Swift Modernization Project](Roadmap.md).
Please upvote or create a [feature request](https://github.com/firebase/firebase-ios-sdk/issues)
to help prioritize any particular cell(s).

|                       | AB  | Ana    | ApC    | ApD    | Ath    | Cor    | Crs    | DB     | Fst    | Fun    | IAM    | Ins    | Msg    | MLM    | Prf    | RC     |    Str |
|   :---                | :--- | :----: | :----: | :----: | :----: | :----: | :----: | :----: | :----: | :----: | :----: | :----: | :----: | :----: | :----: | :----: | :----: |
| **Swift Library**     | ❌   |   ✔   | ❌     |❌     | ❌     | ❌     | ❌      |  ✔     |  ✔    | 1      |  ✔     | ❌    | ❌     | ✔      | ❌     | ❌    | ✔     |
| **API Tests**         | ❌   |  ❌    |  ✔    |❌     | ❌     | ✔       | ❌     | 3      | 2     |  ✔     | 2      | ❌     | ❌     | 2      | ❌    |  ✔     | ✔    |
| **async/await**       | ❌   |  ❌    |  ✔    |❌     | ❌     |  ✔      | ❌     | 3     | ❌     | ❌     | ❌     | ❌    | ❌     | ❌    | ❌     |  ✔    | ✔    |
| **Swift Errors**      |  ❌  |  ❌    | ❌    |❌     | 4      | ❌     | ❌     | ❌     | ❌    | ❌     | ❌     | ❌    | ❌     | ✔      | ❌     | ❌   | 5   |
| **Codable**           | n/a  | n/a     | n/a   |n/a    | n/a     | n/a    |n/a     |  ✔     |  ✔     | 1      | n/a     | n/a   | ❌     | n/a    | n/a    | n/a   |n/a   |
| **SwiftUI Lifecycle** | n/a  |  ❌    | n/a    |❌     | ❌     | n/a    |n/a     | n/a    | n/a    | n/a     | n/a    | n/a   | ❌     | n/a    | n/a    | n/a   |n/a  |
| **Property Wrappers** |  ❌  |  ❌    | ❌    |❌     | ❌     | ❌     | ❌     | ❌     | ✔     | ❌     | ❌     | ❌    | ❌     | ❌    | ❌     | ❌   |❌     |

### Other Projects
- Automatic Swift API generation and coverage validation

## Row Definititions
### Swift Library
A Swift implemented extension library exists. It is deployed as Firebase{Product}Swift CocoaPod and as a Swift Package Manager product.

### API Tests
Tests exist for all Swift APIs. Integration tests are preferred, but compile-only tests are acceptable.

### async/await
API tests include tests for all auto-generated async/await APIs. Implementations are added for
asynchronous APIs that don't have auto-generated counterparts like
[these](https://github.com/firebase/firebase-ios-sdk/blob/master/FirebaseStorageSwift/Tests/Integration/StorageAsyncAwait.swift)
for Storage.

### Swift Error Handling
Swift Error Codes are available instead of NSErrors.

### Codable
Codable is implemented where appropriate.

### SwiftUI Lifecycle
Dependencies on the AppDelegate Lifecycle are migrated to the Multicast AppDelegate.

### Property Wrappers
Property wrappers are used to improve the API.

## Notes
1. In progress at #8854
2. Tests exist. Coverage to be confirmed.
3. Mostly done. Need to review open questions in the RTDB tab [here](https://docs.google.com/spreadsheets/d/1HS4iJBtTHA9E01VrcsiVn_GVOa7KOCcn5LNw3sWlGoU/edit#gid=75586175).
4. Feature Request at #7723 and PR at #9000
5. Started at #9007