# How the zip builder works

This doc is for people who change the zip builder. It explains the rules the tool follows to turn a
`Package.swift` into a zip of `.xcframework`s, and why each rule is there. The
[README](../README.md) covers how to run it, and [configuration.md](configuration.md) covers every
config key.

## The pipeline

The tool is five stages, each a plain function from one value to the next:

```mermaid
flowchart LR
  P["Package.swift"] -- loadPackage --> G["ModulesGraph"]
  G -- makePlan --> R["Plan"]
  R -- customize --> C["Plan (customized)"]
  C -- "buildXCFrameworks (calls makeProject)" --> X[".xcframeworks"]
  X -- makeZip --> Z["Firebase.zip"]
```

- `loadPackage` resolves the package with [SwiftPM](https://github.com/swiftlang/swift-package-manager),
  logs its diagnostics, and throws on errors.
- `makePlan` maps the package one-to-one to a build plan: library targets become frameworks, binary targets
  become binaries, and products become folders. It throws on input it can't plan, such as an unknown `--product` or
  an unsupported SwiftPM feature. `products.exclude`, `products.rename` and `products.add` names
  that match nothing warn and are skipped, like the names `customize` checks.
- `customize` applies the config's customizations, each a function from plan to plan. It never
  throws: a config name that matches nothing logs a warning, so
  `--product` builds keep working while typos stay visible.
- `buildXCFrameworks` writes an Xcode project (`makeProject`), archives it once per destination,
  and creates the `.xcframework`s, taking unchanged ones from the cache.
- `makeZip` packages the `.xcframework`s, and any additional files as denoted by the config.

Every decision happens while planning; the later stages only carry out the plan, so `plan.json`
shows what will be built. Each CLI command runs one stage into the work directory, recomputing the
earlier stages it needs unless you pass their output (`--plan`, `--xcframeworks`).

## The plan

`Plan` is the one model, and the only input the later stages get; the `plan` command writes it as
`plan.json`.

- `Plan`: project-wide `settings` (Xcode settings, already in Xcode's form), `frameworks` in
  dependency order, prebuilt `binaries`, the zip's `folders`, and, in a dynamic release, the
  frameworks `frameworks.static` keeps static (`keptStatic`, not encoded when empty).
- `Framework`: name, module name, source package, sources, headers with their visibility, an
  optional custom module map, resources, settings, dependencies, platforms, bundle ID, version,
  whether it's dynamic, and its post-archive `layout`.
- `Source` and `Dependency` have optional platforms: `nil` means every platform for a source, and
  wherever its framework ships for a dependency.
- `Binary`: a prebuilt `.xcframework`'s name, path, platforms and version.
- `Folder`: a zip folder's frameworks and binaries, plus extra files. Folder `"."` is the zip root.

Paths are relative to the package root, so plans and fingerprints match across machines, and
`plan.json` sorts keys and platform sets, so equal plans are equal bytes. Each stage reads only
its own config sections; anything else reaches it through the plan:

| Stage | Config it reads |
|---|---|
| `makePlan` | `release` (bundle ID prefixes), `products.exclude`/`add`/`rename`/`withoutDependencies`, `frameworks.dynamic`/`static` (with `aggregate`, `merge` and `rename`, for final names), `build.platforms`, `build.linkage` |
| `customize` | `frameworks`, `products`, `build`, `layout`, `zip.files` |
| `makeProject`, `buildXCFrameworks` | none: only the plan |
| `makeZip` | `release.name`, `release.archiveName`, `zip.externalArtifacts`, `products.base.product` |
| `verify` | `products.base.product`, `verify.skipImports` |

The release version is `--version`, else `release.version`. (`Model/Plan.swift`)

## From Package.swift to frameworks

### Shipped products and modules

The shipped products are the root package's library products, minus `products.exclude`, plus
`products.add`; `--product` keeps one, and `--without-dependencies` (only with `--product`) turns
on `products.withoutDependencies` for it. Only modules the shipped products reach are planned, so
test-only targets never ship. Each reachable library target becomes a framework named after the
target, with module name `c99name`
(`GoogleUtilities-Environment` → `GoogleUtilities_Environment`); wrappers are the exception. Each
binary target becomes a `Binary`. Each product becomes a folder named
`products.rename[product] ?? product`, holding everything the product reaches. With
`products.withoutDependencies`, the folder also records the product's own frameworks: its
targets, or what a wrapper target forwards to. It still holds the whole closure until
[Folders and extra files](#folders-and-extra-files), so platform restrictions see every product.
Also:

- Names in `products.exclude` and keys of `products.rename` that aren't library products of the
  root package warn and are skipped. They're checked before `--product` filters, so planning one
  product doesn't warn about the others. A `products.add` target the package doesn't have is
  skipped with a warning, and so is an added product left with no targets.
- Bundle IDs are `<prefix>.<name>`: `release.bundleIdPrefix` for the root package,
  `release.dependencyBundleIdPrefix` (when set) for dependencies. Characters a bundle ID can't
  hold become hyphens (`openssl_grpc` → `openssl-grpc`), as in CocoaPods' bundle IDs.
- The version is the release version for the root package, else the package's resolved version.
  A dependency not resolved to a tag falls back to the release version, with a warning.
- Modules are dynamic from the start, because linker settings are only translated while planning,
  when they're in a dynamic product or when the framework they end up in is dynamic by config:
  with `build.linkage: dynamic`, every framework not in `frameworks.static`; else those in
  `frameworks.dynamic`. A dynamic product's modules stay dynamic even in `frameworks.static`.
  That framework's name is worked out from the config as `customize` will combine and rename
  (aggregate, then merge, then rename), so a renamed framework, a merged companion and an
  aggregated part all link like the framework they end up in, and bring their linker settings
  when it's dynamic. (`Planning/DynamicFrameworks.swift`, `dynamicTargets`,
  `finalFrameworkNames`)
- A dependency on a target, or on a product's targets, becomes a `Dependency`; its platform
  conditions become its platforms, and duplicates merge on the union of their platforms.
  (`Planning/MakePlan.swift`, `makePlan`; `Planning/Dependencies.swift`)

### Wrapper targets

Some targets only exist to make SwiftPM work: umbrella targets, and targets that attach binaries
or platform conditions. They don't become frameworks. Whatever depended on a wrapper depends on
its dependencies instead, where both conditions hold, and so does a folder rooted at one.

A target is a wrapper when all its sources and public headers are code-free: nothing is left after
removing comments, preprocessor directives and whitespace. Stubs (`dummy.m`, forwarding headers)
hold license comments and `#import`s, so they aren't empty, but they're code-free. Headers count
because header-only targets (`FirebaseAuthInterop`) have a code-free `dummy.m` but real headers.

A code-free target with resources other than a privacy manifest isn't a wrapper: its resources
have to ship in a framework (`FirebaseInAppMessaging_iOS`'s storyboard). A privacy manifest alone
doesn't count, because binary wrappers carry one that duplicates the binary's own, so it's
dropped. (`Planning/Wrappers.swift`, `isWrapper`, `isCodeFree`)

### Headers

Headers under SwiftPM's public headers directory (`includeDir`) are public; the rest are project
headers. A mixed-language target's C part counts too. There are no folder- or name-based rules;
anything more is [explicit config](#public-private-and-hidden-headers).

`Headers/` is flat, so two public headers can't share a file name. When they do, a header with
declarations beats a code-free forwarder (nanopb's `spm_headers/pb.h` would include itself once
flattened), else the first wins. The others become project headers, with a warning, when the
project is written. (`Planning/MakePlan.swift`, `headers(of:)`; `Building/GeneratedFiles.swift`,
`resolvingHeaderCollisions`)

### Header search paths

A framework's `HEADER_SEARCH_PATHS` are, without duplicates: its declared paths (resolved against
its target directory, then made relative to the package root; macros and absolute paths stay), its
own source directory, and its own public headers directory when that exists. In the project,
relative paths become `$(SRCROOT)/<path>`, since the project directory is the package root.

Dependencies' public headers directories aren't searched. Every dependency is a framework (or a
cached binary) whose headers come from there, as for the zip's users. Searching its sources too
makes a header reachable twice, since `-I` comes before `-F`, and clang reports every declaration
in it as a duplicate. `CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES` is on because a
public header may include a dependency's header through a declared search path (`<nanopb/pb.h>`);
the shipped framework resolves it through the dependency's framework.

The exception is C++. SwiftPM searches every C-family dependency's include directory, and C++
sources include by the paths that gives them, but a framework's flat `Headers/` only serves
`<Framework/Header.h>`: `<absl/strings/str_cat.h>`, `<openssl/ssl.h>` or a top-level `"pb.h"`
can't be found through it. So a framework with C++ sources (`.cc`, `.cpp`, `.cxx`) also searches
the include directory of each C or C++ library it depends on, directly or not, that has a public
header its framework can't serve: one that isn't directly in a directory named after the
framework (after renaming). Objective-C keeps the usual rule: a module with only Objective-C++
(`.mm`) besides Objective-C doesn't count, and neither do libraries with Objective-C sources,
whose headers come in through modules, where the duplicates happen; Xcode compiles C++ without
modules, so it includes headers as text. Libraries whose headers all sit in
`<Framework>/` (leveldb's `<leveldb/db.h>`) are still found through their frameworks.
(`Planning/HeaderSearchPaths.swift`, `dependencyIncludeDirectories`;
`Planning/SwiftPMSettings.swift`, `frameworkSettings`)

### Umbrella headers and module maps

Xcode generates a framework's module map from a public umbrella named after the module,
`<PRODUCT_MODULE_NAME>.h`. When the project is written, each framework gets:

| The framework has | It gets |
|---|---|
| A custom `module.modulemap` | The map, translated to a framework module map; no umbrella |
| A code-free public `<Module>.h` | Nothing: that header is the umbrella |
| A `<Module>.h` with declarations (`GTMSessionFetcher.h`) | A generated `<Module>-umbrella.h`, and a module map naming it |
| No `<Module>.h` | A generated `<Module>.h`, even for pure Swift |

Only a code-free `<Module>.h` is an umbrella, since real umbrellas only import. A generated one:

- imports each public header as `<Framework/Header.h>`. While building, angle brackets find a
  header through the search paths first, as the framework's own headers do; quoted imports would
  reach the `Headers/` copies and define everything twice;
- imports Foundation and, behind `__has_include`, UIKit, like CocoaPods' umbrellas. Users rely on
  `import <Module>` re-exporting UIKit, and the guard keeps macOS slices building;
- declares `<Module>VersionNumber` and `<Module>VersionString`.

A custom module map is translated line by line: `module X` becomes `framework module <Module>`,
header paths become file names, `export` lines stay, `//` comments go, and Swift sources add the
`<Module>.Swift` submodule. Anything else (submodules, umbrella directories, `link`, `requires`, a
header that isn't public) is an error rather than a guess. (`Building/GeneratedFiles.swift`,
`addUmbrellaHeader`; `Building/ModuleMaps.swift`)

### Resources and privacy manifests

`.process` resources go in the resources phase, localized ones in variant groups. `.copy`
resources are folder references. `.embedInCode` resources become a generated `PackageResources`
Swift struct, as in SwiftPM. No `Bundle.module` accessor is generated, so sources that use it need
a [build mode](#build-mode) where they don't.

A framework ships one privacy manifest, and Xcode can't copy two same-named files into one
framework. So several manifests (after merging) are combined: `NSPrivacyTracking` is OR-ed,
tracking domains and collected data types are unioned, accessed API types are unioned by type with
their reasons, and other keys keep their first value. Keeping only one would drop reasons. The
plan keeps every manifest, so `plan.json` stays truthful. (`Building/GeneratedFiles.swift`,
`combinedPrivacyManifest`)

### Build settings

The project settings hold what every framework needs (`BUILD_LIBRARY_FOR_DISTRIBUTION`,
`SKIP_INSTALL = NO`, `DEFINES_MODULE`, no code signing until packaging), and what SwiftPM sets for
package targets (ARC, modules, `USE_HEADERMAP = NO`, generated `Info.plist`s, `SWIFT_PACKAGE`).
`SWIFT_COMPILATION_MODE = wholemodule` optimizes each Swift module as a whole, as SwiftPM's release
builds and the CocoaPods-era zip did; Xcode's default compiles file by file, which optimizes less
and exports thousands of extra internal symbols.
`VERSIONING_SYSTEM = apple-generic` and `CURRENT_PROJECT_VERSION = 1` give every framework version
symbols and a `CFBundleVersion`. `TARGETED_DEVICE_FAMILY` leaves out 6 ("Optimize for Mac"), so
Mac Catalyst keeps the iPad idiom; 6 would change how storyboards and asset catalogs compile.

Declared settings are evaluated for Release only, the one configuration archived (and the
project's only one). A value that holds on every platform is plain, on some platforms
conditional, on none (Linux-only) dropped. `.define` values with spaces are quoted;
`.linkedFramework`/`.linkedLibrary` become `OTHER_LDFLAGS` only for dynamic frameworks, since
static ones don't link; one conditioned on iOS links on Mac Catalyst too, which compiles the iOS
code (`TARGET_OS_IOS`). SwiftPM keeps Catalyst apart, but there the app links, and module imports
autolink; Xcode compiles C++ and Objective-C++ without modules, so a dynamic framework built from
them would miss the framework (Firestore's `UIKit`). CocoaPods' `ios` covered Catalyst too
(`linkingPlatforms`). `.swiftLanguageMode` becomes one unconditional `SWIFT_VERSION`; the rest
keep SwiftPM's names.

Xcode conditions on the SDK (`KEY[sdk=iphoneos*]`), and a conditional value replaces the plain
one, so conditional lists start with `$(inherited)`. macOS and Catalyst share `macosx`, so their
values go through `KEY_MACOS`/`KEY_CATALYST`, picked by `IS_MACCATALYST`. Target list settings
also start with `$(inherited)`, so project definitions reach every target.
(`Planning/SwiftPMSettings.swift`, `projectSettings`, `evaluateBuildSettings`, `translate`;
`Building/MakeProject.swift`, `xcodeSettings`)

### Platforms and deployment targets

There are six platforms: `ios`, `catalyst`, `macos`, `tvos`, `watchos`, `visionos`. Each archives
a device and a simulator destination, except the Mac ones. Frameworks start on `build.platforms`,
then [platform restrictions](#platform-restrictions) narrow them. A binary's platforms come from
its `.xcframework`'s `Info.plist`. Conditions map strictly, as in SwiftPM: `.iOS` isn't Catalyst.

Deployment targets come from the root package's declared platforms. SwiftPM's derived versions
raise declared ones to its own minimums (macOS 11 → 12), so they're only the fallback. Catalyst has
no setting of its own; Xcode derives it from `IPHONEOS_DEPLOYMENT_TARGET`, which macOS ignores, so
its version goes on `IPHONEOS_DEPLOYMENT_TARGET[sdk=macosx*]` when it differs from iOS.

Each target's `SUPPORTED_PLATFORMS` lists only its platforms' SDKs, so no scheme builds it
elsewhere; Catalyst adds `iphoneos`, and a target without Catalyst gets
`SUPPORTS_MACCATALYST = NO`. (`Model/Platform.swift`; `Planning/SwiftPMSettings.swift`,
`deploymentTargets`; `Building/MakeProject.swift`, `targetSettings`)

### Unsupported features

`makePlan` fails clearly on what has no simple framework equivalent: system library targets, build
tool plugins, macros, module aliases, and binary targets that aren't `.xcframework`s. Every module
the products reach is checked, wrappers and binaries included. Trait conditions are fine: SwiftPM
evaluates them while loading the graph. (`Planning/MakePlan.swift`, `unsupportedFeature(of:)`)

## Customizations

`customize` runs these steps in order; each reads its own keys and does nothing when they're empty.
Merging and renaming come first so later steps see final names, and folders are arranged last so
platform restrictions still see every product. (`Customizing/Customize.swift`, `customize`)

### Aggregating packages

`frameworks.aggregate` merges a package's frameworks into one named after it (`GoogleUtilities-*`
→ `GoogleUtilities`): an empty static framework with the package's version and bundle ID prefix,
unless a part already has that name. Only planned frameworks are combined, so test helpers don't
ship, and a `--product` build combines fewer parts. Parts' custom module maps are dropped, so the
aggregate gets a generated umbrella. (`Customizing/Merge.swift`, `aggregatingPackages`)

### Merging targets

`frameworks.merge` compiles companions into a parent (`FirebaseAuthInternal` into
`FirebaseAuth`): it absorbs their sources, headers, resources, settings and dependencies, and
references to them point at the parent.

- When both sides have a single value, the parent's wins (identity, `SWIFT_VERSION`). Lists are
  unioned without duplicates; a flag and its argument (`-framework Security`) count as one item.
- Files are de-duplicated by path. A companion's `<Companion>.h` and custom module map only
  described its SwiftPM module, so they're dropped.
- A companion in `frameworks.platforms` compiles only there: its sources and its dependencies get
  those platforms (`AppCheckRecaptchaProvider` → `RecaptchaInterop`). (`Customizing/Merge.swift`,
  `merging`, `Framework.absorb`; `Model/BuildSettings.swift`, `combined`)

### Renaming

`frameworks.rename` renames a framework before anything is built, so its module, umbrella and
bundle ID use the new name (`GTMSessionFetcherCore` → `GTMSessionFetcher`). Binaries can't be
renamed: their name is inside their slices. A taken name is skipped, because names identify
frameworks in folders, dependencies and the cache. A rename whose old name is missing while its
new name is already in the plan is already done, and is skipped without a warning (a debug log):
a package that ships a target either from source or as a prebuilt binary named like the rename's
target (Firestore's C++ dependencies) works with one config. A rename where neither name is in
the plan still warns, so typos stay visible. `finalFrameworkNames` skips the same renames.
(`Customizing/Merge.swift`, `renaming`)

### Public, private and hidden headers

`frameworks.publicHeaders` adds the headers under directories as public (Firestore's forwarding
headers). `frameworks.privateHeaders` ships matching headers in `PrivateHeaders/`, and
`frameworks.hiddenHeaders` makes them project headers so they don't ship. Patterns are globs on
file names; header files are those with one of XcodeProj's header extensions (`.h`, `.inc`, …).
(`Customizing/Customize.swift`, `addingPublicHeaders`)

### Platform restrictions

SwiftPM platforms are package-wide, so which platforms a product ships for is a release decision.
A framework or binary ships on the union, over every product (folder) containing it, of
`products.platforms[folder] ?? build.platforms`, including folderless products. That's narrowed
to `build.platforms` and to its own `frameworks.platforms` entry.

Product platforms are explicit config, never inferred from conditions on a product's wrapper.
That would be a heuristic, and under SwiftPM's strict mapping it would still drop the Catalyst
slices Firebase ships. A product missing the key fails loudly on the unsupported platform instead
of shipping something wrong.

Each dependency then applies only where both sides are built, and is dropped if that's nowhere. A
framework or binary on no platform can't become an `.xcframework`, so it's dropped from the plan,
its folders and every dependency, with a warning. (`Customizing/Customize.swift`,
`restrictingPlatforms`)

### Build mode

Sources may need to compile differently than under SwiftPM; Firebase compiles as CocoaPods did,
which also avoids `Bundle.module`.

- `build.defineSwiftPackage: false` removes `SWIFT_PACKAGE` from every setting and variant.
- `build.defines`, `build.versionMacro` and `build.swiftConditions` extend the project settings.
- `build.architectures` is keyed by destination, so a device-only `arm64_32` skips the simulator.
- `build.deploymentTargets` overrides the declared ones; Catalyst compiles the iOS sources, so it's
  raised to iOS unless configured too.
- `build.swiftVersion` sets `SWIFT_VERSION` per framework, or for all with `"*"`.
- `frameworks.dynamic` and `build.linkage: dynamic` make frameworks dynamic here too, for names
  that only exist after merging or aggregating (the aggregate `customize` adds starts static),
  and `frameworks.static` keeps them static in a dynamic release. Names that aren't frameworks in
  the plan warn and are skipped. See [Linkage](#linkage).
- `build.settings` runs last, so a configured key replaces every value and variant of it.
  (`Customizing/Customize.swift`, `applyingBuildMode`)

### Layout

`layout` records what's applied to each finished framework: its privacy bundle name (only with a
manifest), resource bundle name, and `Info.plist` values (only for static frameworks: they're
workarounds for static frameworks embedded in apps, and `MinimumOSVersion = 100.0` would stop an
app embedding a dynamic one from launching). See
[Post-archive layout](#post-archive-layout). (`Customizing/Customize.swift`, `applyingLayout`)

### Folders and extra files

The last step drops `products.withoutFolder`, adds `products.extraFrameworks`, and removes
`products.base`'s frameworks from other folders, only when the base folder exists, so `--product`
keeps shared frameworks. `zip.files` entries join their folder; `"."` becomes a folder named
`"."`, first. Frameworks in no folder are warned about. (`Customizing/Folders.swift`,
`arrangingFolders`)

With `products.withoutDependencies`, each folder first keeps only its product's own frameworks
(`Folder.ownFrameworks`), intersected with what it holds, so one that ships on no platform stays
out; then the other keys apply as above. Merges, aggregates and renames rewrite `ownFrameworks`
as they rewrite `frameworks` (`replacingReferences`), so it names what the targets became. It's
applied last because platform restriction needs the whole closure, and then cleared: the final
plan's folders list what ships, and `plan.json` has no `ownFrameworks`. The dependencies left out
are still built into `<work-dir>/xcframeworks/` and aren't warned about.

## Building

### One archive per destination

An archive contains every framework its scheme builds. So there's one scheme per destination
(`ios`, `ios-simulator`, `catalyst`, …) building every framework shipped there, and each
`.xcframework` is created from its slices in those archives. Xcode builds each framework once per
destination; destinations run one after another. The cost: a framework can't have different
settings in different products. Logs go to `<work-dir>/logs/`, and derived data stays in
`<work-dir>/DerivedData/<destination>` with Xcode's compilation cache on, so a kept work directory
recompiles little. (`Building/BuildXCFrameworks.swift`, `buildXCFrameworks`)

### The framework cache

The cache holds whole `.xcframework`s, before layout, as
`<cache-dir>/<fingerprint>/<Name>.xcframework`. Slices all change together, so caching them
separately saves nothing.

Xcode doesn't know about the cache: a dependency that's a target is always built from source. So
cached frameworks become binaries in the plan, linked like SwiftPM binary targets, and only changed
frameworks and their dependents compile; with no changes, nothing is archived. Dependents compile
against a cached framework's headers and `.swiftinterface`, as the zip's users do.

Xcode only exposes a linked `.xcframework`'s module to targets that link it, while a built target's
module is visible to every later target. Sources may import any transitive dependency, as in
SwiftPM (`FirebaseAuth` imports `FirebaseCoreInternal` through `FirebaseCore`), so each static
framework left to build also links every binary it reaches, on the platforms of the paths that
reach it. Static frameworks don't absorb what they link, so the output doesn't change. Dynamic
frameworks link everything they reach anyway (see [Linkage](#linkage)).

Storing is atomic and first-writer-wins: a copy goes into a temporary directory in the cache and
is renamed into place, so a half-written entry never counts, and an existing entry is kept. A
build sharing the cache never loses an entry it's linking, and equal fingerprints mean equivalent
entries. `build --project` builds a hand-edited project without touching the cache.
(`Building/BuildXCFrameworks.swift`, `replacingCachedFrameworks`; `Building/FrameworkCache.swift`)

### Linkage

Frameworks are static unless planning made them dynamic: `build.linkage: dynamic` (or
`--linkage dynamic`) makes every framework built from source dynamic, as the legacy dynamic zip
did through CocoaPods' `use_frameworks!`, except those in `frameworks.static`. Prebuilt binaries
are never changed, and the archive name and folders are the same as for a static zip, so each
linkage gets its own work directory.

`frameworks.static` is the mirror image of `frameworks.dynamic`: it only applies to a dynamic
release, as `frameworks.dynamic` only applies to a static one, and it names frameworks the same
way (final names, so a merged companion or an aggregated part stays static with its framework).
A framework in a `.dynamic` product stays dynamic, since the package's author declared it so;
listing it warns. The plan records the frameworks a dynamic release keeps static as
`Plan.keptStatic`, which isn't encoded when empty, so other plans don't change.

- **No static code in dynamic frameworks.** A dynamic framework that links a static library
  copies its code in, so its symbols are duplicated wherever the app, or another framework, links
  it too. Before anything is built, the build inspects one slice of each binary a dynamic
  framework reaches (`file`, as `diff` reads binary kinds) and fails on a static one, naming the
  framework and the binary: build that dependency from source, or keep the framework static. A
  binary whose kind can't be told doesn't count. It also fails when a dynamic framework reaches a
  framework in `Plan.keptStatic`, naming both: make the dependency dynamic, or keep the dependent
  static too. Static frameworks may reach dynamic ones. Only kept frameworks count: in a static
  release, a framework in `frameworks.dynamic` or a `.dynamic` product may still absorb the
  static frameworks it reaches, as SwiftPM's dynamic products do, so static releases build as
  before.
- **Dynamic frameworks link everything they reach,** targets and cached binaries alike, on the
  platforms of the paths that reach them. A static framework links only cached binaries it
  reaches, which its output doesn't absorb; a dynamic framework would get extra load commands, so
  without this a cached build would differ from an uncached one. The cached-framework swap never
  adds anything else to a dynamic framework.
- **`layout.infoPlist` is skipped for dynamic frameworks;** they keep Xcode's `Info.plist`
  (see [Layout](#layout)).
- **C and C++ libraries built from source are dynamic frameworks like the rest.** Their linker
  settings (`.linkedLibrary("z")`) become `OTHER_LDFLAGS`, Xcode links libc++ for C++ sources,
  and their dependents find their headers through include directories
  (see [Header search paths](#header-search-paths)).

Dynamic frameworks never reuse static cache entries: `isDynamic` and `MACH_O_TYPE` are part of
the framework's fingerprint. A framework `frameworks.static` keeps static is planned as in a
static release, so it shares that release's cache entries. (`Building/Linking.swift`,
`checkDynamicFrameworksLinkNothingStatic`; `Building/BuildXCFrameworks.swift`,
`replacingCachedFrameworks`)

### Fingerprints

A fingerprint covers `fingerprintFormat`, the Xcode version, the project settings, the framework's
model fields except `layout`, its destinations, the contents of its sources, headers, resources
and module map, its binaries' contents, and its framework dependencies' fingerprints. A change
anywhere below a framework rebuilds it, without re-hashing dependencies' files.

A source can include a header that's in no list through a declared search path; Firebase targets
search the repo root. So headers under every search path outside the framework's own directory
(the deepest one holding its sources and headers) count too. Any header change under the repo root
then rebuilds most Firebase frameworks: the price of never shipping a stale one. The walk skips
directories that only hold header copies (hidden ones, the work and cache directories, bundles,
`DerivedData`, other work directories with a `plan.json`); otherwise building would change
fingerprints, and they would differ between machines.

Generated files aren't hashed: they follow from the plan and the tool's code. When that output
changes, bump `fingerprintFormat`. The hashed text is pinned by
`FrameworkCacheTests.goldenFingerprints`. (`Building/FrameworkCache.swift`, `Fingerprints.of`)

### Post-archive layout

Finished frameworks and binaries are copied to `<work-dir>/xcframeworks/`, and the layout is
applied to the copies, so cache entries stay untouched. In each slice the privacy manifest and the
other resources move into their bundles, and the `Info.plist` values are set. A new bundle gets the
framework's `Info.plist` without `CFBundleExecutable`, named after the bundle, as a `BNDL`;
macOS-style slices use `Versions/A/Resources` and `Contents/`. (`Building/Layout.swift`)

## Packaging

`makeZip` builds `<work-dir>/dist/<release.name>/` and zips it:

1. Copies each folder's `.xcframework`s and files; `"."` is the root. The README is a `zip.files`
   entry, so Firebase's text stays out of the tool.
2. Places `zip.externalArtifacts`, downloaded once into `<work-dir>/downloads/`. A plain directory
   contributes its entries; a file or bundle is placed as is.
3. Writes `METADATA.md`: each folder's frameworks, the base folder first and the others marked
   `(~> <base>)`, then every framework's and binary's version.
4. With `--sign`, signs every unsigned `.xcframework`. Vendors' signed binaries keep their
   signature, since re-signing would replace it in a real release.
5. Zips with `ditto --norsrc --noextattr --noacl`. Extended attributes are per machine
   (`com.apple.provenance`), and `ditto` would store them as `__MACOSX/` or `._*` entries.
   (`Packaging/MakeZip.swift`, `makeZip`; `Packaging/Metadata.swift`)

## Verify

`verify` checks behavior the build can't see, on any distribution directory or zip:

1. Every folder links into an app with `-ObjC`, with the base folder (`products.base.product`),
   since other folders don't repeat its frameworks.
2. Every module imports from Swift and Objective-C, except `.xcframework`s in
   `verify.skipImports`. One without a module map fails: nobody can import it, and a distribution
   can't tell a module-less vendor binary from a broken framework.
3. Each platform has device and simulator slices (macOS and Catalyst have no simulator), and every
   slice the `Info.plist` lists exists.
4. Every signature verifies; `--require-signatures` (on with `release --sign`) fails unsigned ones.

Checks 1 and 2 use iOS device slices: the one platform every Firebase folder ships, and an SDK
every Xcode has. A lone top-level directory (the zip's `Firebase/`) is unwrapped.

A distribution built without its dependencies can't link or import on its own (FirebaseAuth
needs FirebaseCore), so `verify` takes `dependencies`: `.xcframework`s it needs but doesn't ship.
Check 1 links them with every folder, and its title says how many; check 2 adds them to the
framework search paths. They aren't checked themselves, and ones the distribution ships are
ignored. `release` passes the `.xcframework`s in `<work-dir>/xcframeworks/` only when
`products.withoutDependencies` is on, so other releases verify as before; `verify --dependencies
<dir>` reads them from a directory. (`Inspecting/Verify.swift`; `Inspecting/Distribution.swift`,
`readDistribution`, `readXCFrameworks`)

## Diff

`diff` compares two distributions for pull request comments: folders, loose files, and frameworks
added, removed or moved. Per framework: slices, architectures, binary kind, headers, `Modules/`
files, module maps (by trimmed lines), `CFBundleShortVersionString`, `MinimumOSVersion` and
`CFBundleIdentifier`, resource bundles, and exported symbols; not signatures. Identical per-slice
differences merge into one entry, and symbol lists keep exact counts but at most 20 names.
`--exit-code` exits 1 on differences, after the report is written.

A release version bump changes every framework built from the root package. When at least two
frameworks' `CFBundleShortVersionString` changed, all from the same old value to the same new one
in every slice, `diff` reports it once, as `Release version: X → Y (N frameworks)`, and drops
those entries; their other differences stay. Frameworks from dependency packages keep their own
versions and usually don't change. Mixed bumps, a bump in only some slices, or a single
framework's (a dependency's update) stay per framework. The bump is a difference, in every format.
`CFBundleVersion` is `1` in every built framework, so it isn't compared. Nothing else `diff` reads
carries the version: `METADATA.md` is a loose file, compared by name, headers by path, and
`build.versionMacro` only changes binary contents, which `diff` doesn't compare.

The Markdown shows at most 40 lines per framework and 100 items per layout section, and drops
sections past 60,000 bytes, under GitHub's 65,536-character comment limit. `--format
github-comment` is the same Markdown arranged as a comment: the `--title` line, then either
"✅ The distributions match." or the summary (the release version and the table of counts) with
the rest inside `<details>`; the 60,000 bytes include the title. `--title` also starts
`--format markdown`; with `text` or `json` it's an error, so a missing title never goes
unnoticed. The tool adds nothing PR-specific: the caller supplies the title.
(`Inspecting/Diff.swift`, `Inspecting/RenderDiff.swift`)

## Non-goals

- No mixed folder layouts: a dynamic and a static zip share their archive name and folders, so
  each is built into its own work directory.
- No heuristics or name-based inference: `includeDir`, the code-free rule, and explicit config.
- No version inference from `Package.swift`: the version is `--version` or `release.version`.
- No mixing a `--product` build with other builds. Its aggregates hold only the parts that product
  reaches, under the same name and version as a full build's, so they can't stand in for those.
- No per-product settings: a framework is built once per destination for every product.
- No renaming after building, and no renaming of prebuilt binaries.
- Only iOS is checked for linking and imports.
