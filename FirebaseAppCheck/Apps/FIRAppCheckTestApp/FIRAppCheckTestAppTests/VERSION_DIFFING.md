# Running this suite against a different Firebase version

The point of this suite is not only to check that App Check works, but to
detect where v12 *behaves differently* from v11. Those differences are the
migration risk, and most of them are invisible to the compiler: a renamed error
domain, a renumbered error code, a callback that moved off the main queue, a
notification key that changed spelling.

This file describes how the suite is written so that such a diff is possible,
and what still has to be built before one can be run end to end.

## Why the assertions look the way they do

Assertions against SDK symbols cannot detect drift. This:

```swift
#expect(error.domain == AppCheckErrorDomain)
```

passes on every version, including one that renamed the domain, because both
sides of the comparison move together. It asserts only that the SDK is
self-consistent.

So values that escape the SDK are pinned to literals instead, in
`PublicContractTests.swift`:

```swift
#expect(AppCheckErrorDomain == "com.firebase.appCheck")
```

That is deliberately brittle. It is supposed to fail when the string changes,
because code we do not control matches on that string.

The rule of thumb: if a value can be observed by an app without importing a
Firebase symbol, pin it to a literal. That covers error domains, error code raw
values, notification names, `userInfo` keys, and Keychain service and account
formats. `LegacyStorageAddressParityTests.swift` does the same for storage
addresses.

Behaviour that cannot be expressed as a constant is pinned by observation
instead: which queue a completion handler runs on, whether a near-expiry token
is reused, whether concurrent readers coalesce onto one request. Those live in
`CoreTokenLifecycleTests.swift` and `InteropTests.swift`.

## The awkward part: the test app lives inside the repository under test

The Xcode project references Firebase as a *local* Swift package:

```
XCLocalSwiftPackageReference "firebase-ios-sdk"
    relativePath = "../../../../firebase-ios-sdk"
```

That path is the very repository this test app is committed to. Checking out an
11.x tag to test against v11 would also revert the test app, deleting the suite
you were trying to run.

A git worktree avoids this. It gives a second checkout at a different revision,
backed by the same object store, without a second clone:

```console
git -C ~/Developer/firebase-ios-sdk worktree add ~/Developer/fis-v11 11.15.0
```

Then point the package reference at the worktree instead:

```
relativePath = "../../../../fis-v11"
```

The test app stays exactly where it is, at its current revision, and links
against v11.

> [!IMPORTANT]
> If you added a local `app-check` package reference to override App Check
> Core, remove it for a v11 run. Leaving it in place would link v11 Firebase
> against v12 App Check Core, which is not a configuration anyone ships and
> would produce a meaningless diff. Without the override, SwiftPM resolves App
> Check Core to whatever version the v11 `Package.swift` pins.

## Not yet possible: the app target does not compile against v11

Two v12-only changes in the host app block this today. Both are real migration
findings in their own right and are why the suite cannot simply be pointed at
v11 and run.

1. `AppDelegate.setupAppCheck` constructs `RecaptchaProviderFactory(siteKey:)`.
   In v11 the site key was set on `FirebaseOptions.recaptchaSiteKey`, and
   `RecaptchaProviderFactory()` took no arguments. v12 removed the option and
   marked the bare initialiser `NS_UNAVAILABLE`.

2. `TestProviderRegistry` falls back to `AppDelegate.installedProviderFactory`,
   which is fine on both versions, but the registry itself is only needed
   because of how this suite is structured, not because of the SDK.

Only the first is a genuine incompatibility. Making the app build on both
versions needs a compilation condition around the provider construction, for
example an `APPCHECK_LEGACY_V11` flag set only in the diffing configuration:

```swift
#if APPCHECK_LEGACY_V11
  options.recaptchaSiteKey = siteKey
  providerFactory = RecaptchaProviderFactory()
#else
  providerFactory = RecaptchaProviderFactory(siteKey: siteKey)
#endif
```

This has not been added yet. It is deliberately left out until someone actually
wants a v11 run, because an unexercised compatibility shim rots.

## What a diff run tells you

Three outcomes, in increasing order of interest.

| Result | Meaning |
| :--- | :--- |
| Green on both | The behaviour is genuinely unchanged. |
| Red on v12, green on v11 | A regression, or an intentional change that needs a migration-guide entry. |
| Red on v11, green on v12 | The test encodes a v12 assumption. Check whether the v12 behaviour is the intended one before treating v11 as wrong. |

The third case is easy to get wrong. A test written against v12 and then run
against v11 will sometimes fail because v11 was *correct* and v12 changed, so a
v11 failure is not automatically a v11 bug.

## Suites by version sensitivity

| Suite | Sensitivity |
| :--- | :--- |
| `Public API contract` | Highest. Every assertion is a literal, and exists only to catch drift. |
| `Legacy storage address parity` | High. Pins the Keychain addresses that decide whether upgrading users keep their cached tokens. |
| `Language interoperability` | High. Error translation and callback queues are exactly where a Swift rewrite leaks. |
| `Core token lifecycle` | Moderate. Caching, coalescing, and expiry are behaviour rather than constants. |
| `AppCheckObjCAPITests` | High, and the only coverage written in Objective-C, so the only thing that can catch a regression in the Swift-to-ObjC projection. |
