# Configuration

Everything specific to one release lives in a single config file: which products ship, how
targets become frameworks, how they're compiled, and what else goes in the zip. The tool itself
has no Firebase knowledge. Firebase's config is `zip_builder.jsonc` at the repository root, and the
examples below come from it.

To see what a config change does without building anything, run `plan` and read its warnings and
`<work-dir>/plan.json` (see [The plan](how-it-works.md#the-plan)).

## The config file

**Lookup.** With `--config <path>`, the tool reads that file; a missing file is an error. Without
it, the tool looks in `--package-path` (default `.`) for `zip_builder.jsonc`, then
`zip_builder.json`. When both exist it reads `zip_builder.jsonc` and warns that the other is
ignored. When neither exists, the stage fails with `No config: … Add it, or pass --config.`
`verify` is the exception: it looks in the current directory, and runs without a config when
there's none (see [verify](#verify)).

**Format.** Both file names are read as JSON5, so `//` and `/* */` comments and trailing commas
work in either. Prefer `.jsonc`: editors and code review render its comments as comments.

**Required keys.** Only `release.name` and `release.bundleIdPrefix`. Every other key, and every
group except `release`, is optional and takes the default listed below. A decoding error names the
key path, e.g. `Invalid config at <path>: build.platforms.1: …`.

**Names that don't match.** A name the plan doesn't have (a product, target, framework, folder,
package, destination or header pattern) is a warning, `<key>: <name> isn't <kind>; skipped.`, not
an error. This keeps `--product` usable: it plans one product, so most names in the full config
don't exist in its plan, while typos still show up. Product names (`products.exclude`, keys of
`products.rename`) are checked against all of the package's library products, so `--product`
doesn't make them warn. A `products.add` target the package doesn't have is skipped, and so is a
product left with no targets.

**Unknown keys.** A key that isn't on this page (say `"privateHeader"`) is a warning too, e.g.
`frameworks: privateHeader isn't a config key; ignored.`, since it would otherwise silently do
nothing. Array elements show their index (`products.add[0]: …`). Keys of maps, such as
`products.rename` and `build.settings`, are names, so they're never reported. The repo's
`zip_builder.jsonc` must load without warnings; a test checks it.

**Value spellings.** Platforms are `ios`, `catalyst`, `macos`, `tvos`, `watchos` and `visionos`.
Destinations (only in `build.architectures`) are the platform names, plus `ios-simulator`,
`tvos-simulator`, `watchos-simulator` and `visionos-simulator`.

**Which name goes where.** Products become folders (renamed by `products.rename`), and targets
become frameworks (combined by `frameworks.aggregate` and `frameworks.merge`, then renamed by
`frameworks.rename`). Each key expects the name from one point in that chain:

| Name | Keys |
|---|---|
| Product names, as in `Package.swift` | `products.exclude`, `products.add[].name`, keys of `products.rename`, `--product` |
| Folder names, after `products.rename` | `products.withoutFolder`, `products.base.product`, keys of `products.platforms` and `products.extraFrameworks`, `zip.files[].to`, `zip.externalArtifacts[].to` |
| Target names | `products.add[].targets`, `frameworks.merge`, keys of `frameworks.rename` |
| Package names | `frameworks.aggregate` |
| Framework or binary names, after merging and renaming | `frameworks.publicHeaders`, `frameworks.platforms`, `frameworks.dynamic`, `frameworks.static`, `build.swiftVersion`, `layout.privacyBundle`, `layout.resourceBundles`, values of `products.extraFrameworks`, `products.base.frameworks` |
| Module names in the finished zip | `verify.skipImports` |
| Header file name patterns | `frameworks.privateHeaders`, `frameworks.hiddenHeaders` |

**Who reads what.** Planning and `customize` read every group except `verify`. Packaging reads
`release`, `zip` and `products.base`; `verify` reads `products.base` and `verify`. The build stage
reads no config: everything it needs is already in the plan.

## release

The release's identity.

- **`name`** (string, required). Names the source project (`<name>.xcodeproj`), the distribution
  folder (`dist/<name>/`, the zip's top-level folder) and `{name}` in `archiveName`. Firebase:
  `"Firebase"`.
- **`version`** (string, default none). The release version: root-package frameworks get it as
  their bundle version, and it fills `{version}` and `build.versionMacro`. `--version` takes
  precedence, and one of the two is required whenever a stage plans or packages; nothing is
  inferred from `Package.swift`. Frameworks from dependency packages get their package's resolved
  version instead.
- **`bundleIdPrefix`** (string, required). Root-package frameworks get the bundle ID
  `<prefix>.<target>`, with characters a bundle ID can't hold turned into hyphens. Firebase:
  `"com.google.firebase"`.
- **`dependencyBundleIdPrefix`** (string, default `bundleIdPrefix`). The prefix for frameworks from
  dependency packages. Firebase: `"org.cocoapods"`, which keeps the bundle IDs the CocoaPods-built
  zip gave GoogleUtilities, nanopb and the rest.
- **`archiveName`** (string, default `"{name}-{version}.zip"`). The zip's file name, written to
  `<work-dir>/`. **Gotcha:** only `{name}` (`release.name`) and `{version}` are replaced. Firebase:
  `"{name}-{version}-latest.zip"`, the legacy zip's name, which the quickstart workflow looks for.

## products

Which products ship, and how the zip's folders are arranged. Every library product of the root
package ships as a folder holding every framework and binary it needs (only its own with
`withoutDependencies`), minus `exclude`, plus `add`.

> **Gotcha:** `exclude`, `add` and the keys of `rename` use the package's **product** names. Every
> other key here uses **folder** names, i.e. the names after `rename`.

- **`exclude`** (list of product names, default `[]`). Products that don't ship. Firebase: the
  Combine community products, `FirebaseAnalyticsCore`, `FirebaseAnalyticsIdentitySupport`, and
  products that left the zip in 13.0.0.
- **`add`** (list of `{ "name", "targets" }`, default `[]`). A product that `Package.swift` doesn't
  declare, made of the listed targets (any target in the package graph). Firebase:
  `{ "name": "FirebaseABTesting", "targets": ["FirebaseABTesting"] }`, because the zip has an A/B
  Testing folder but the package has no such product.
- **`rename`** (product name → folder name, default `{}`). Firebase: drops the `-Beta` suffix of
  `FirebaseAppDistribution-Beta` and `FirebaseInAppMessaging-Beta`.
- **`withoutFolder`** (list of folders, default `[]`). Products that are built but get no folder.
  A framework that ends up in no folder at all is warned about. Firebase: `FirebaseCore` and
  `FirebaseInstallations`, whose frameworks ship in the `FirebaseAnalytics` folder.
- **`base`** (`{ "product": folder, "frameworks": [names] }`, default none). The folder that owns
  shared frameworks: the listed frameworks and binaries are removed from every other folder. It
  only applies when that folder exists, so `--product` with another product keeps its shared
  frameworks. `METADATA.md` marks the folders that need it, and `verify` links every folder
  together with it. Firebase: `FirebaseAnalytics`, with FirebaseCore, GoogleUtilities, nanopb and
  the other frameworks every product needs.
- **`platforms`** (folder → platforms, default `{}`). A folder without an entry ships on
  `build.platforms`. A framework ships on the union of the platforms of every product that needs
  it (counting `withoutFolder` products, and before `base` is applied), narrowed by
  `build.platforms` and `frameworks.platforms`. **Gotcha:** restricting a product doesn't restrict
  a dependency that an unrestricted product also needs. Firebase restricts App Distribution,
  Database, Firestore, In-App Messaging and Performance to their podspecs' platforms, e.g.
  `"FirebaseAppDistribution": ["ios", "catalyst"]`; the platform conditions in `Package.swift`
  aren't inferred.
- **`extraFrameworks`** (folder → framework or binary names, default `{}`). Adds frameworks to a
  folder that doesn't depend on them; `base` is applied afterwards. Firebase:
  `"FirebasePerformance": ["FirebaseRemoteConfig", "FirebaseSharedSwift"]`, as the legacy zip did.
- **`withoutDependencies`** (bool, default `false`). Each folder holds only its product's own
  frameworks, not what they depend on, like the legacy zip builder's
  `--disable-build-dependencies`. A product's own frameworks are the frameworks its targets
  become after `frameworks.aggregate`, `merge` and `rename`: a target merged into a parent counts
  as the parent, and an aggregated one as its package's framework. A wrapper target counts as what
  it forwards to. The dependencies are still planned and built, because the product needs them
  to compile, and land in `<work-dir>/xcframeworks/` with the rest; they just aren't in any
  folder, so they aren't zipped or warned about. Platforms still come from every product that
  needs a framework, dependencies included, and `extraFrameworks` and `base` apply as usual.
  `release` verifies such a zip by linking it against the dependencies in
  `<work-dir>/xcframeworks/` (`verify --dependencies` does the same by hand).
  `--without-dependencies` turns it on for `--product`. Firebase doesn't set it.

  > **Gotcha:** a wrapper forwards to everything it depends on, so a product whose target is a
  > wrapper listing its dependencies (Firebase's `FirebaseAnalytics` product, through
  > `FirebaseAnalyticsWrapper`) still ships them. Point the product at the targets that should
  > ship, and let those targets depend on the rest.

> **Gotcha:** a framework or binary that ends up on no platform (say, a product restricted to
> `["visionos"]` while `build.platforms` lacks visionOS) can't be built. It's dropped from the
> plan, every folder and every dependency, with the warning `<name> ships on no platform;
> dropped.`

## frameworks

How targets become frameworks. Each library target becomes one framework, except code-free
wrapper targets (see [Wrapper targets](how-it-works.md#wrapper-targets)). `customize` applies
these keys in order: `aggregate`, `merge`, `rename`, `publicHeaders`, `privateHeaders`,
`hiddenHeaders`, `platforms`, `dynamic` and `static`.

> **Gotcha:** `aggregate`, `merge` and the keys of `rename` use names from before renaming. Every
> key applied after `rename`, here and in `build`, `layout` and `products`, uses the **new** name.
> That's why Firebase's `layout.privacyBundle` names `GTMSessionFetcher`, not
> `GTMSessionFetcherCore`.

- **`aggregate`** (list of package names, default `[]`). Combines every framework from a dependency
  package into one framework named after the package. Only the parts the release uses are
  included, so test helpers don't ship; with `--product`, only the parts that product reaches. The
  name is the package's `name:` in its `Package.swift`. Firebase: `["GoogleUtilities"]`, which
  turns GoogleUtilities-Logger, GoogleUtilities-Network and the rest into one
  `GoogleUtilities.xcframework`, as CocoaPods did.
- **`merge`** (parent target → companion targets, default `{}`). The parent absorbs its companions'
  sources, headers (except a companion's own umbrella header), resources, settings and
  dependencies, and references to a companion point at the parent. Firebase: SwiftPM splits some
  pods into several targets (often a Swift one and an Objective-C one), so `"FirebaseAuth":
  ["FirebaseAuthInternal"]` and six other entries put each pod back into one framework.
- **`rename`** (framework → new name, default `{}`). The framework is built under the new name:
  framework, module, `PRODUCT_NAME` and the end of its bundle ID. **Gotcha:** prebuilt binaries
  can't be renamed, and neither can a framework whose new name is already taken; both are skipped
  with a warning. A rename whose old name isn't in the plan while its new name already is (a
  framework or a binary) is already done: it's skipped quietly (logged with `-v`), so one config
  serves a package that ships a target either from source or as a prebuilt binary. If neither
  name is in the plan, it warns. Firebase: `"GTMSessionFetcherCore": "GTMSessionFetcher"`, the
  module name CocoaPods used; and, with source Firestore (`FIREBASE_SOURCE_FIRESTORE=1`),
  `FirebaseFirestoreInternalWrapper` → `FirebaseFirestoreInternal`, `abseil` → `absl`,
  `gRPC-Core` → `grpc` and `gRPC-cpp` → `grpcpp`, the names the prebuilt binaries already have.
- **`publicHeaders`** (framework → directories, default `{}`). Every header under these
  package-root-relative directories, recursively, becomes a public header of the framework (added,
  or made public if it's already one of its headers). A directory without headers is warned about.
  Firebase: `FirebaseFirestore` gets the Objective-C headers in
  `FirebaseFirestoreInternal/FirebaseFirestore`, and `FirebaseStorage` its `Typedefs`.
- **`privateHeaders`** (list of file name patterns, default `[]`). Headers whose file name matches
  a pattern (a shell glob such as `*Private.h`), in any framework, ship in `PrivateHeaders/`.
  Firebase: `["FBLPromisePrivate.h"]`, as in the podspec's `private_header_files`.
- **`hiddenHeaders`** (list of file name patterns, default `[]`). Matching headers don't ship;
  they're still used to compile. Applied after `privateHeaders`, so a header matching both is
  hidden. Firebase: `["IsAppEncrypted.h"]`, which GoogleUtilities vendors but its podspec keeps
  private.
- **`platforms`** (framework or binary → platforms, default `{}`). Narrows where it ships. For a
  companion in `merge`, it instead limits where the companion's sources and dependencies compile
  inside the parent. Firebase: `RecaptchaInterop` and `leveldb` ship on their podspecs' platforms,
  and the `AppCheckRecaptchaProvider` companion only compiles into `AppCheckCore` for iOS and Mac
  Catalyst.
- **`dynamic`** (list of framework names, default `[]`). Builds these as dynamic frameworks
  (`MACH_O_TYPE = mh_dylib`) in a static release. Frameworks of a `.dynamic` library product in
  `Package.swift` are dynamic too, and with `build.linkage: "dynamic"` every framework is except
  those in `static`; otherwise frameworks are static. A merged or aggregated framework's parts,
  and a renamed framework, are found by the final name, so their linker settings come along.
  Firebase sets none.
- **`static`** (list of framework names, default `[]`). The mirror image of `dynamic`: keeps these
  static when `build.linkage` is `"dynamic"`, and does nothing in a static release. Names are
  matched as in `dynamic`, so a merged companion or an aggregated part stays static with its
  framework, and a renamed framework is found by its new name; names that aren't frameworks in
  the plan warn and are skipped. **Gotcha:** a framework of a `.dynamic` library product stays
  dynamic, since the package declares it so; listing it warns. **Gotcha:** no dynamic framework
  may depend on a listed one, even through other frameworks, or its code would be copied into
  the dynamic framework. The build fails, naming both; keep the dependent static too, or don't
  list the dependency. Firebase sets none: its dynamic zip builds Firestore from source.

## build

How the project is compiled. Every key here changes fingerprints, so changing one rebuilds the
affected frameworks (see [Fingerprints](how-it-works.md#fingerprints)).

- **`platforms`** (list of platforms, default `["ios", "catalyst", "macos", "tvos", "watchos"]`).
  The release's platforms; every framework is narrowed to them. visionOS is opt-in. `--platforms`
  takes precedence for one run (CI's quickstart tests build just `ios` on pull requests). Firebase
  uses the default.
- **`deploymentTargets`** (platform → version, default `{}`). Overrides the minimum versions from
  `Package.swift`. Raising iOS raises Mac Catalyst too, unless `catalyst` has its own entry.
  Firebase uses `Package.swift`'s.
- **`architectures`** (destination → architectures, default `{}`). Becomes
  `ARCHS[sdk=<sdk>*]` in the project. **Gotcha:** it's keyed by **destination** name, not platform:
  `watchos` is the device and `watchos-simulator` the simulator, so a device-only architecture
  doesn't reach the simulator. `macos` and `catalyst` share the `macosx` SDK, so either name sets
  both. Firebase: `"watchos": ["arm64", "arm64_32"]`, the legacy zip's watchOS device slice.
- **`defineSwiftPackage`** (bool, default `true`). When `false`, `SWIFT_PACKAGE` is removed from
  the preprocessor definitions and Swift compilation conditions everywhere. Firebase: `false`, so
  sources take their `COCOAPODS` / `FIREBASE_BUILD_ZIP_FILE` paths (GoogleUtilities, for example,
  reports the `zip` deployment type).
- **`defines`** (list, default `[]`). Preprocessor macros added to the project's
  `GCC_PREPROCESSOR_DEFINITIONS`. Firebase: `["COCOAPODS=1", "FIREBASE_BUILD_ZIP_FILE=1"]`.
- **`swiftConditions`** (list, default `[]`). Added to `SWIFT_ACTIVE_COMPILATION_CONDITIONS`.
  Firebase: `["COCOAPODS"]`.
- **`swiftVersion`** (framework or `"*"` → version, default `{}`). Sets `SWIFT_VERSION`; a
  framework's own entry beats `"*"`. Firebase: `{ "*": "5.0", "FirebaseAILogic": "6.0" }`, the
  language modes of the podspecs.
- **`settings`** (setting → string or list of strings, default `{}`). Any Xcode build setting, set
  on the project after everything else. It replaces the setting and all its variants
  (`KEY[sdk=…]` and the like) in the project and every framework. Firebase sets none; for example,
  `{ "ENABLE_MODULE_VERIFIER": "YES" }` would turn on Xcode's module verifier.
- **`versionMacro`** (string, default none). Defines `<macro>=<release version>` as a preprocessor
  macro. Firebase: `"Firebase_VERSION"`, which FirebaseCore reports at runtime.
- **`linkage`** (`"static"` or `"dynamic"`, default `"static"`). With `"dynamic"`, every framework
  built from source is dynamic, as if it were in `frameworks.dynamic`, except those in
  `frameworks.static`; prebuilt binaries are never changed. `--linkage` takes precedence. The
  archive name and folders stay the same, so build each linkage into its own `--work-dir`.
  **Gotcha:** a dynamic framework can't depend, even through other frameworks, on a static
  prebuilt binary or a framework in `frameworks.static`: its code would be copied into the
  framework. The build fails, naming both; build that dependency from source (or don't keep it
  static), or keep the framework static. Firebase uses the default; for a dynamic zip, pass
  `--linkage dynamic` with `FIREBASE_SOURCE_FIRESTORE=1`, so Firestore and its C++ dependencies
  are built from source as dynamic frameworks instead of linked as static prebuilt binaries.

## layout

Changes applied to each finished `.xcframework`, in every slice. They're applied to copies after
the framework is built and cached, so changing them never recompiles anything (see
[Post-archive layout](how-it-works.md#post-archive-layout)).

- **`privacyBundle`** (framework or `"*"` → bundle name, default `{}`). Moves
  `PrivacyInfo.xcprivacy` into `<bundle>.bundle`; `{target}` in the name is replaced with the
  framework name, and a framework's own entry beats `"*"`. Only frameworks that have a privacy
  manifest get a bundle; without an entry, the manifest stays at the framework's root. Firebase:
  `{ "*": "{target}_Privacy", "GTMSessionFetcher": "GTMSessionFetcher_Core_Privacy" }`, the
  bundle names CocoaPods used.
- **`resourceBundles`** (framework → bundle name, default `{}`). Moves a framework's other
  resources into `<bundle>.bundle`. Firebase: `"FirebaseInAppMessaging":
  "InAppMessagingDisplayResources"`, the bundle its code loads its UI from.
- **`infoPlist`** (key → string, default `{}`). Values set in every static framework's
  `Info.plist` (binaries keep theirs). Firebase: `"MinimumOSVersion": "100.0"`, which works around
  an App Store validation failure for embedded static frameworks (#12439). **Gotcha:** dynamic
  frameworks don't get these values: they keep the `Info.plist` Xcode generates, since an
  embedded dynamic framework with `MinimumOSVersion` 100 would stop the app from launching.
  Privacy and resource bundles apply to both.

A created bundle gets an `Info.plist` derived from its framework's.

## zip

What else goes in the zip, next to the frameworks.

- **`files`** (list of `{ "to", "files" }`, default `[]`). Copies package-root-relative files into
  a folder, or into the zip root when `to` is `"."`. **Gotchas:** `to` is a folder name after
  `products.rename`, and a folder that doesn't exist (including one in `products.withoutFolder`)
  is warned about and skipped. Files are copied by file name, without their directories, so two
  files with the same name can't go in one folder. A missing file fails packaging. Firebase: the
  zip root gets the legacy zip's `README.md`, `NOTICES`, `Firebase.h` and `module.modulemap`, and
  the `FirebaseCrashlytics` folder gets the `run` and `upload-symbols` scripts.
- **`externalArtifacts`** (list of `{ "to", "url", "subpath", "stripSignatures" }`, default `[]`).
  Prebuilt zips downloaded and unpacked into folder `to` (`"."` is the zip root; a missing folder
  is created). Each URL is downloaded once, into `<work-dir>/downloads/`, and reused. The archive's
  top-level entries go into the folder, or with `subpath` the item at that path inside the
  archive: a plain directory contributes its entries, and a file or bundle (such as an
  `.xcframework`) is placed as is. `stripSignatures` (default `false`) removes every
  `_CodeSignature` directory, so `--sign` signs the result with the rest. Firebase has none.

## verify

How `verify` checks a finished distribution. A distribution doesn't record which folder is the
base or which modules nobody imports, so `verify` reads them from the config: `--config`, else
`./zip_builder.jsonc` or `./zip_builder.json` in the current directory. Without a config, every
folder links on its own and every module is import-checked.

- **`skipImports`** (list of module names, default `[]`). Modules the import check reports as
  skipped instead of importing them. Firebase skips `AppCheckCore` (its module and class share a
  name, which breaks its own `.swiftinterface`), the C++ frameworks `absl`, `grpc`, `grpcpp` and
  `openssl_grpc` (prebuilt, or built from source and renamed with source Firestore; their module
  maps aren't importable from Swift or Objective-C), and the C++-only `leveldb`. **Gotcha:**
  entries are `.xcframework` names, which is what the report lists. A framework named unlike its
  module (`gRPC-Core`, module `gRPC_Core`) never imports, since clang finds a framework module by
  the framework's name; neither does a C++-only one. List those if nobody imports them directly.

`verify` also reads `products.base.product`: every folder is linked together with that folder.

## Recipes

After each change, run `plan` and check its warnings and `plan.json`.

**Ship an extra file, such as a README.** Paths are relative to the package root; `"."` is the
zip root.

```jsonc
"zip": {
  "files": [{ "to": ".", "files": ["ReleaseTooling/Template/README.md"] }]
}
```

**Restrict a product's platforms.** Use the folder name. To restrict one framework instead, use
`frameworks.platforms` with its framework name.

```jsonc
"products": { "platforms": { "FirebaseInAppMessaging": ["ios", "catalyst"] } },
"frameworks": { "platforms": { "RecaptchaInterop": ["ios", "catalyst"] } }
```

**Merge a companion target into its parent.** Both are target names. Add the companion to
`frameworks.platforms` if it should only compile on some platforms.

```jsonc
"frameworks": {
  "merge": { "AppCheckCore": ["AppCheckRecaptchaProvider"] },
  "platforms": { "AppCheckRecaptchaProvider": ["ios", "catalyst"] }
}
```

**Aggregate a dependency package into one framework.** Use the package's name.

```jsonc
"frameworks": { "aggregate": ["GoogleUtilities"] }
```

**Make headers private or hidden.** Patterns match file names in every framework.

```jsonc
"frameworks": {
  "privateHeaders": ["FBLPromisePrivate.h"],  // ships in PrivateHeaders/
  "hiddenHeaders": ["IsAppEncrypted.h"]       // doesn't ship
}
```

**Rename a framework.** Then use the new name in every later key (`layout`, `build.swiftVersion`,
`products.base.frameworks`, …).

```jsonc
"frameworks": { "rename": { "GTMSessionFetcherCore": "GTMSessionFetcher" } },
"layout": { "privacyBundle": { "GTMSessionFetcher": "GTMSessionFetcher_Core_Privacy" } }
```

**Add an external artifact.** For example, a vendor's prebuilt `.xcframework` from a zip, placed
in its own folder, with its signature removed so `--sign` signs it with the rest (the URL and
names are illustrative):

```jsonc
"zip": {
  "externalArtifacts": [{
    "to": "VendorSDK",
    "url": "https://example.com/VendorSDK-1.2.3.zip",
    "subpath": "Frameworks/VendorSDK.xcframework",
    "stripSignatures": true
  }]
}
```

**Skip an import check.** For a module that ships but can't be imported from Swift or
Objective-C, use the module name as it appears in the zip.

```jsonc
"verify": { "skipImports": ["leveldb"] }
```

**Ship products without their dependencies.** Each folder then holds only what its product's own
targets become; what they depend on is built into `<work-dir>/xcframeworks/` but not zipped. For
one product, pass `--product <name> --without-dependencies` instead.

```jsonc
"products": { "withoutDependencies": true }
```
