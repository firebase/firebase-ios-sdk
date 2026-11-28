# FirebaseCore API baselines

These files record FirebaseCore's public API so that changes to it are caught
in review. They guard the reimplementation of FirebaseCore in Swift, which must
keep the public Swift and Objective-C APIs unchanged.

| File | Contents |
|---|---|
| `swift/<platform>.json` | `swift-api-digester` dump of the Swift view of the `FirebaseCore` module, per platform. |
| `swift/FirebaseCore.swiftinterface` | The same API as readable Swift (iOS), for reviewers. |
| `objc/FirebaseCore.symbols.json` | Normalized `clang -extract-api` symbol graph of the Objective-C public headers. |
| `metadata.json` | The toolchain that generated the baselines. |
| `allowlist.json` | Reviewed, intentional differences. |

## Checking

```sh
DEVELOPER_DIR=/Applications/Xcode_26.4.app/Contents/Developer \
  scripts/core_api/core_api.py check
```

Use the Xcode recorded in `metadata.json`, which is the Xcode that the
`api-baselines` job in `.github/workflows/sdk.core.yml` uses. The Swift view of
an API can differ between compiler versions. That job uploads the current API
as the `core-api-current` artifact, which can replace these files after an
approved change.

`check` fails if a declaration is removed, renamed, or changes type,
optionality, `@Sendable`, or deprecation, and also if a declaration is added.
Objective-C method nullability isn't compared directly, because `clang
-extract-api` drops it. The Swift gate covers it, because the Swift view shows
nullability as optionality.

## Changing the API

FirebaseCore's public API shouldn't change. If a change has been reviewed and
approved:

* For a small, known difference, add an entry to `allowlist.json` with a
  `pattern` that matches the reported line and a `reason`.
* Otherwise regenerate the baselines with `scripts/core_api/core_api.py update`
  and include the regenerated files in the same pull request.
