# Zip modernization checklist: from CocoaPods parity to a SwiftPM-style zip

Today the new zip builder reproduces the CocoaPods-era zip as closely as it can, so the old
pipeline remains a safe fallback. This checklist lists every parity workaround, in the config
([zip_builder.jsonc](file:///Users/daymxn/Documents/firebase-ios-sdk/zip_builder.jsonc)) and in
the tool's code. Each item says what to change, why, the impact, and what must change with it.

> [!IMPORTANT]
> Items marked **Breaking** change what zip users install, import or link. Group them into a major
> release with release notes, and roll out the rest in minor releases. Run the zip diff, `verify`
> and the quickstart CI (static and dynamic) for every item.

## Summary

| # | Change | Where | Breaking? | Effort |
|---|---|---|---|---|
| 1 | Default archive name | `release.archiveName` | Automation only | Config |
| 2 | Xcode's default watchOS architectures | `build.architectures` | No | Config |
| 3 | Dependency bundle IDs | `release.dependencyBundleIdPrefix` | No | Config |
| 4 | SwiftPM header visibility | `frameworks.privateHeaders`, `hiddenHeaders` | Rarely | Config |
| 5 | Package language modes | `build.swiftVersion` | No | Config, plus fixes |
| 6 | Drop the version macro | `build.versionMacro` | No | Config, after a check |
| 7 | AppCheckCore import check | `verify.skipImports` | No | Upstream fix |
| 8 | Ship the SwiftPM Analytics variants | `products.exclude` | Additive | Config |
| 9 | visionOS | `build.platforms` | Additive | Config |
| 10 | Platforms from Package.swift | `products.platforms`, `frameworks.platforms` | Additive | Tool + config |
| 11 | SwiftPM build mode | `build.defineSwiftPackage`, `defines`, `swiftConditions` | **Yes** (runtime) | Config + tool + SDK |
| 12 | SwiftPM bundle names | `layout.privacyBundle`, `resourceBundles` | **Yes** (with 11) | Config + tool |
| 13 | Separate companion frameworks | `frameworks.merge` | **Yes** | Config |
| 14 | Separate GoogleUtilities frameworks | `frameworks.aggregate` | **Yes** (rarely felt) | Config |
| 15 | SwiftPM module name for GTMSessionFetcher | `frameworks.rename` | **Yes** | Config |
| 16 | SwiftPM public headers | `frameworks.publicHeaders` | **Yes** (Objective-C) | Config |
| 17 | No `Firebase` umbrella module | `zip.files` | **Yes** (Objective-C) | Config + README |
| 18 | Umbrella headers without UIKit | `GeneratedFiles.swift` | **Yes** (implicit imports) | Tool |
| 19 | Simpler folder layout | `products.base`, `withoutFolder`, `extraFrameworks`, `add`, `rename` | **Yes** (install steps) | Config + README |
| 20 | Dynamic by default | `build.linkage` | **Yes** (install steps) | Config |
| 21 | Drop the `MinimumOSVersion` workaround | `layout.infoPlist` | No (with 20) | Config |
| 22 | Keep SwiftPM's header folder tree | Tool (`Headers/` layout) | Rarely | Tool |
| 23 | No CocoaPods text in METADATA.md | `Packaging/Metadata.swift` | No | Tool |

---

## Low risk: cleanups that don't change how users install

### 1. Default archive name
- **Change:** remove `release.archiveName` (`"{name}-{version}-latest.zip"`), so the zip is `Firebase-<version>.zip`.
- **Why:** `-latest` is a legacy name with no meaning in a versioned file.
- **Impact:** automation that downloads the zip by name: the quickstart workflow (`infra.zip_quickstart.yml` looks for `*-latest.zip`), the release scripts, and possibly users' CI. Users who download by hand aren't affected.
- **With it:** update those workflows and scripts.

### 2. Xcode's default watchOS architectures (TODO #4)
- **Change:** remove `build.architectures.watchos`.
- **Why:** it only exists to keep the legacy `watchos-arm64_arm64_32` slice name.
- **Impact:** a different watchOS slice identifier inside each `.xcframework`. Xcode picks slices by platform, not by name, so users shouldn't notice. Check that the slices still cover every device Firebase supports.

### 3. Dependency bundle IDs
- **Change:** remove `release.dependencyBundleIdPrefix` (`org.cocoapods`).
- **Why:** `org.cocoapods.*` bundle IDs for GoogleUtilities, nanopb and the others only mimic CocoaPods.
- **Impact:** bundle IDs inside those frameworks change. Nothing at runtime depends on them, though it's worth checking that App Store validation doesn't flag the new IDs.

### 4. SwiftPM header visibility
- **Change:** remove `frameworks.privateHeaders` (`FBLPromisePrivate.h`) and `frameworks.hiddenHeaders` (`IsAppEncrypted.h`).
- **Why:** they copy the podspecs' `private_header_files`. With SwiftPM, a header's visibility comes from whether it's in the include directory.
- **Impact:** those headers become public, as they are for SwiftPM users. If they shouldn't be public, move them out of the include directory in the source packages, which fixes it for SwiftPM too.

### 5. Package language modes
- **Change:** remove `build.swiftVersion` (`"*": "5.0"`, AILogic `6.0`).
- **Why:** the podspecs build everything in Swift 5 mode. Without the override, each target uses the language mode its Package.swift declares, which the tool already reads.
- **Impact:** targets that declare Swift 6 get strict concurrency checking. Expect compile errors to fix in the SDK. The `.swiftinterface`s change, but users' code doesn't need to.

### 6. Drop the version macro
- **Change:** remove `build.versionMacro` (`Firebase_VERSION`).
- **Why:** Package.swift already defines `Firebase_VERSION` for FirebaseCore (`cSettings`). The config key defines it in every framework, the way the podspecs did.
- **Check first:** whether any target other than FirebaseCore reads `Firebase_VERSION`. If one does, define it in that target's Package.swift settings, so SwiftPM users get it too, then remove the key.

### 7. AppCheckCore import check
- **Change:** fix AppCheckCore's module and class name clash upstream, then remove it from `verify.skipImports`.
- **Why:** the clash breaks its own `.swiftinterface`. That's a real bug, not a parity choice. Keep the C++ entries (`absl`, `grpc`, `grpcpp`, `openssl_grpc`, `leveldb`).

### 8. Ship the SwiftPM Analytics variants
- **Change:** remove `FirebaseAnalyticsCore` and `FirebaseAnalyticsIdentitySupport` from `products.exclude`.
- **Why:** SwiftPM users can already choose Analytics without the IDFA support; zip users can't.
- **Impact:** two more folders. This is additive, but check that the `products.base` layout still makes sense (see 19). Keep excluding the `*Combine-Community` products, which aren't official.

---

## Platform coverage (additive)

### 9. visionOS
- **Change:** add `"visionos"` to `build.platforms`. The tool's default leaves it out to match the old zip.
- **Why:** Firebase supports visionOS through SwiftPM.
- **Impact:** new visionOS slices, a larger zip and longer builds. Users get visionOS support.

### 10. Platforms from Package.swift
- **Change:** teach the tool to read a product's platforms from Package.swift (its wrapper targets' platform conditions), then remove `products.platforms` and `frameworks.platforms`.
- **Why:** both keys copy the podspecs' platform lists by hand, so they can drift from Package.swift.
- **Impact:** any product that SwiftPM supports on more platforms gains slices. Catalyst needs care: the podspecs ship Catalyst, and SwiftPM's `.iOS` covers it. **This needs a tool feature.**

---

## Build mode: the largest change in behavior

### 11. SwiftPM build mode
- **Change:** in `build`, set `defineSwiftPackage: true`, remove `COCOAPODS=1` from `defines`, and remove `swiftConditions: ["COCOAPODS"]`. Decide separately about `FIREBASE_BUILD_ZIP_FILE=1` (see below).
- **Why:** the zip's code then compiles exactly as it does for SwiftPM users, so there's one set of code paths to test instead of two.
- **Impact (breaking at runtime if done wrong):**
  - Code chooses between `#if SWIFT_PACKAGE` and `#if COCOAPODS` for its imports, resource lookups and behavior. For example, `FIRIAMDefaultDisplayImpl.m` looks up `Firebase_FirebaseInAppMessaging_iOS` under `SWIFT_PACKAGE` and `InAppMessagingDisplayResources` otherwise.
  - Swift targets that use `Bundle.module` need the accessor SwiftPM generates. The tool would have to generate it.
  - GoogleUtilities reports its deployment type from these defines (today `zip`). Keep `FIREBASE_BUILD_ZIP_FILE=1` if you want zip installs to keep showing up as `zip` in usage data, and check that it still takes priority over `SWIFT_PACKAGE`.
- **With it:** item 12, a tool feature for `Bundle.module`, and a full quickstart pass, especially for In-App Messaging UI, resources and privacy manifests.

### 12. SwiftPM bundle names
- **Change:** replace `layout.privacyBundle` (`{target}_Privacy`, `GTMSessionFetcher_Core_Privacy`) and `layout.resourceBundles` (`InAppMessagingDisplayResources`) with SwiftPM's names (`<Package>_<Target>.bundle`). This probably needs a small tool option or default.
- **Why:** the bundle names have to match what the `SWIFT_PACKAGE` code paths look for.
- **Impact:** **this must change at the same time as item 11.** Changing either one alone means resources go missing at runtime.

---

## How frameworks are split and named (breaking: users link different frameworks)

### 13. Separate companion frameworks
- **Change:** remove `frameworks.merge`. Today AuthInternal, CrashlyticsSwift, DatabaseInternal, InAppMessagingInternal and `_iOS`, RemoteConfigInternal, SessionsObjC and AppCheckRecaptchaProvider are merged into their parent frameworks.
- **Why:** the zip's frameworks then match SwiftPM's modules one for one. The tool no longer has to merge headers, sources and settings, the most complicated customization it does.
- **Impact:** users must add and embed the companion `.xcframework`s; the folders and METADATA.md list them. Public APIs and import lines don't change, since the parent modules re-export their companions.

### 14. Separate GoogleUtilities frameworks
- **Change:** remove `frameworks.aggregate` (`GoogleUtilities`).
- **Why:** SwiftPM ships `GoogleUtilities-Environment`, `-Logger` and so on as separate modules.
- **Impact:** about ten small frameworks instead of one. `@import GoogleUtilities` stops working, which apps rarely do. Install steps change, unless the folder layout hides it (see 19).

### 15. SwiftPM module name for GTMSessionFetcher
- **Change:** remove `"GTMSessionFetcherCore": "GTMSessionFetcher"` from `frameworks.rename`, and its `GTMSessionFetcher_Core_Privacy` privacy bundle name (item 12).
- **Why:** CocoaPods shipped the `GTMSessionFetcher/Core` subspec as `GTMSessionFetcher`; SwiftPM's module is `GTMSessionFetcherCore`.
- **Impact:** apps that `import GTMSessionFetcher` directly must change the import. Check other Google SDKs that zip users combine with Firebase, such as Google Sign-In.
- **Keep:** the source-Firestore renames (`FirebaseFirestoreInternal`, `absl`, `grpc`, `grpcpp`). Those are the names the prebuilt binaries ship with in every zip, so dropping them would only make the dynamic zip differ from the static one.

### 16. SwiftPM public headers
- **Change:** remove `frameworks.publicHeaders` (FirebaseFirestore → `FirebaseFirestoreInternal/FirebaseFirestore`, FirebaseStorage → `Typedefs`).
- **Why:** these add headers the podspecs exposed but SwiftPM doesn't.
- **Impact:** Objective-C users who include those headers through `FirebaseFirestore` or `FirebaseStorage` must include them from `FirebaseFirestoreInternal`, or rely on the module's re-exports. Swift users aren't affected.

### 17. No `Firebase` umbrella module
- **Change:** remove `CoreOnly/Sources/Firebase.h` and `module.modulemap` from `zip.files`, and rewrite the README template for per-module imports.
- **Why:** `#import "Firebase.h"` and `@import Firebase` are CocoaPods-era conveniences. SwiftPM users import each module.
- **Impact:** Objective-C projects that use the umbrella must switch to per-module imports. Keep `NOTICES` and Crashlytics' `run` and `upload-symbols`, which aren't parity items.

### 18. Umbrella headers without UIKit
- **Change:** a tool change. The generated umbrella header always imports UIKit "like CocoaPods' umbrellas" ([GeneratedFiles.swift](file:///Users/daymxn/Documents/firebase-ios-sdk/scripts/zip_builder/Sources/ZipBuilder/Building/GeneratedFiles.swift#L116-L125)). Make that a config switch, then turn it off.
- **Why:** SwiftPM's generated umbrellas don't re-export UIKit. Today `import FirebaseX` quietly brings UIKit in.
- **Impact:** code that uses UIKit types without importing UIKit itself stops compiling, in users' apps and possibly in the SDK. Fix the SDK first.

---

## Zip layout and install experience (breaking: install steps)

### 19. Simpler folder layout
- **Change:** rethink `products.base`, `products.withoutFolder`, `products.extraFrameworks` (TODO #7), `products.add` (FirebaseABTesting) and `products.rename` (`-Beta` suffixes).
- **Why:** each copies a quirk of the old layout:
  - shared frameworks live only in the Analytics folder;
  - Core and Installations have no folder of their own;
  - Performance carries RemoteConfig and SharedSwift;
  - ABTesting gets a folder although Package.swift has no ABTesting product.
- **Two natural targets:**
  - **Self-contained product folders:** each folder holds everything its product needs (drop `base`, `withoutFolder` and `extraFrameworks`). Frameworks repeat across folders, but users can drag in exactly one folder.
  - **One flat folder of every `.xcframework`,** with METADATA.md listing which ones each product needs. This is the closest to a SwiftPM-style binary distribution and has no duplicates.
- **Also:** drop `products.add` FirebaseABTesting (it's still built as RemoteConfig's dependency), and decide whether to keep the `-Beta` renames (folder names users type) or use SwiftPM's names.
- **Impact:** install instructions and anyone's scripts that copy folders.

### 20. Dynamic by default
- **Change:** ship the dynamic zip as the main one (`build.linkage: dynamic`), possibly as Xcode's mergeable libraries later.
- **Why:**
  - It's how most binary SDKs ship today.
  - It removes static-library problems: duplicate symbols, the `-ObjC` linker flag, and the `MinimumOSVersion` workaround.
  - It matches how SwiftPM handles dynamic products.
- **Impact:**
  - Users switch to "Embed & Sign".
  - The release build needs source Firestore (`FIREBASE_SOURCE_FIRESTORE=1`), because the prebuilt FirebaseFirestoreInternal is static, unless a dynamic Firestore binary becomes available.
  - Builds take longer, because the C++ code is compiled from source.
  - App launch time can change with many dynamic frameworks; mergeable libraries help with that.

### 21. Drop the `MinimumOSVersion` workaround (#12439)
- **Change:** remove `layout.infoPlist` (`MinimumOSVersion: "100.0"`).
- **Why:** it works around an App Store validation failure for embedded static frameworks. Dynamic frameworks already skip it.
- **Impact:** none once 20 is done. Before 20, only remove it after confirming App Store validation passes without it.

### 22. Keep SwiftPM's header folder tree
- **Change:** a tool feature: keep each framework's include-directory tree under `Headers/` instead of flattening it, at least for C and C++ libraries.
- **Why:**
  - It's how SwiftPM exposes headers.
  - It removes the ~100 header-name collision warnings in source-Firestore builds.
  - It makes the C++ headers usable from the zip, as CocoaPods' `header_mappings_dir` did.
  - It could replace the C++ header search path exception in `HeaderSearchPaths.swift`.
- **Impact:** frameworks' header paths and fingerprints change. Objective-C frameworks with flat include directories don't change.

### 23. No CocoaPods text in METADATA.md
- **Change:** a tool change. METADATA.md says the xcframeworks "map to these versions of the Firebase SDKs in CocoaPods" ([Metadata.swift](file:///Users/daymxn/Documents/firebase-ios-sdk/scripts/zip_builder/Sources/ZipBuilder/Packaging/Metadata.swift#L56-L59)). Move that text into the config, or make it generic.
- **Why:** it's outdated once CocoaPods is gone. It's also Firebase-specific text in `Sources/`, which breaks the tool's own rule.
- **Impact:** METADATA.md wording only.

---

## Keep: these aren't parity workarounds

- **iOS linker settings also apply to Catalyst.** That's Apple's `TARGET_OS_IOS` meaning; a dynamic Catalyst slice needs it.
- **`@rpath` install names, and bundle IDs cleaned the way Xcode does.** That's standard framework behavior.
- **`NOTICES`, Crashlytics' `run` and `upload-symbols`, and the README** (rewritten in 17).
- **The C++ entries in `verify.skipImports`,** and `frameworks.static` as a tool feature.
- **The source-Firestore renames** (see 15).

## Afterwards: simplify the tool

Once Firebase's config no longer uses them, these features exist only for parity. Delete them if no other user of the tool needs them; each one removed takes code, tests and docs with it:
- `frameworks.merge` and `aggregate`, the largest customization code (`Customizing/Merge.swift`);
- `frameworks.publicHeaders`, `privateHeaders` and `hiddenHeaders`;
- `products.base`, `withoutFolder` and `extraFrameworks`;
- `layout.infoPlist` and `layout.privacyBundle` renaming (if SwiftPM names become the default);
- `build.defineSwiftPackage` and `swiftConditions`;
- the UIKit import in generated umbrellas (18).

## Suggested order

```mermaid
flowchart LR
  A["Minor releases: 1–8, 21 (if validated)"] --> B["Additive: 9, 10"]
  B --> C["Major release: 11 + 12 together"]
  C --> D["Same or next major: 13–19"]
  D --> E["20 dynamic by default, then 21, 22"]
  E --> F["Simplify the tool"]
```

Do 11 and 12 on their own first: they change runtime behavior and need the most testing. Frameworks
and layout (13–19) change install steps, so ship them together with one migration guide rather than
one major release after another.
