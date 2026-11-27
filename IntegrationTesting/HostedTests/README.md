# Hosted tests

`HostedTests.xcodeproj` runs SDK test suites that need an app process. It has a
blank host app, `FirebaseTestHost`, for iOS and tvOS. Each SDK adds its own test
target and scheme, and the test target links the SDK from the repo's
`Package.swift` through a local package reference (`../..`).

A host app gives tests what Swift Package Manager test bundles don't have:

- Keychain access. Without a host, `SecItemAdd` can fail with
  `errSecMissingEntitlement` (-34018).
- `UIApplication.shared` (`[UIApplication sharedApplication]` in Objective-C)
  with an app delegate.
- A main bundle.

The `HostSmokeTests` target checks that the host provides these, and shows the
pattern for SDK test targets.

## Try hostless first

Most tests don't need a host. Keep a test in the SDK's Swift Package Manager
test target, using fakes for the keychain, the application, and the network
where needed. Move it here only after it fails without a host on the CI
simulators.

UI tests, end-to-end apps, and sample apps that contain real app code stay in
their own projects.

## Run the tests

Open `HostedTests.xcodeproj` in Xcode and test a scheme on an iOS or tvOS
simulator, or run from the repo root:

```sh
scripts/build.sh HostedTests-<scheme> iOS
scripts/build.sh HostedTests-<scheme> tvOS
```

For example, `scripts/build.sh HostedTests-HostSmokeTests iOS`. The optional
third argument is `build` or `build-for-testing` to build without running the
tests, or `test-without-building` to run tests built by an earlier
`build-for-testing`.

## Add an SDK's tests

1. In Xcode, add a **Unit Testing Bundle** target named `<SDK>HostedTests`, for
   example `InstallationsHostedTests`, with `FirebaseTestHost` as the target to
   be tested.
2. Put its sources in a folder named `<SDK>HostedTests` next to the project and
   add the folder as a synchronized folder, so that adding test files later
   doesn't change `project.pbxproj`.
3. In the target's **Frameworks and Libraries**, add only that SDK's products
   from the `Firebase` package. Never link Firebase products into
   `FirebaseTestHost`: the test bundle would then load a second copy of the SDK.
4. Match `HostSmokeTests`'s build settings: iOS and tvOS deployment target 17.0
   (XCTest needs 17.0 to link), no development team, and warnings as errors.
   Hosted tests therefore aren't compiled at the SDK's minimum deployment
   target; the SDK's Swift Package Manager unit tests are.
5. If the tests need a `GoogleService-Info.plist`, copy `HostSmokeTests`'s
   **Copy GoogleService-Info.plist** run script phase to the new target, and set
   **User Script Sandboxing** to **No** for the target. The phase copies
   `TestConfig/<target>/GoogleService-Info.plist` into the test bundle, not the
   host app, so SDKs never share a plist. Read it with
   `Bundle(for: SomeTestClass.self)`, not `Bundle.main`. If the file is missing,
   the phase removes any copy left by an earlier build, and the tests that need
   it should skip themselves, or fail when CI requires them.
6. Add a shared scheme named `<SDK>HostedTests` (for example, duplicate
   `HostSmokeTests` and change its test target). Keep it under
   `xcshareddata/xcschemes`.
7. Run `scripts/build.sh HostedTests-<SDK>HostedTests iOS`. `scripts/build.sh`
   doesn't need a new case.

### Secrets

Real `GoogleService-Info.plist` files aren't checked in. List the encrypted
file and its destination in `scripts/secrets/<SDK>.json`:

```json
[
    {
        "encrypted": "scripts/gha-encrypted/<SDK>/GoogleService-Info.plist.gpg",
        "destination": "IntegrationTesting/HostedTests/TestConfig/<SDK>HostedTests/GoogleService-Info.plist"
    }
]
```

`.gitignore` already ignores `GoogleService-Info.plist` files under
`TestConfig`. Only `HostSmokeTests`'s file, which has fake values, is checked
in.

### CI

Run the scheme from the SDK's `sdk.<sdk>.yml` workflow, not from
`infra.hosted_tests.yml`, which runs only `HostSmokeTests`:

- Add `IntegrationTesting/HostedTests/**` to the workflow's `pull_request` path
  filters, so that changes to the shared host run the SDK's hosted tests too.
- Decrypt the secrets, then run the tests, for example:

  ```sh
  scripts/repo.sh decrypt --json scripts/secrets/<SDK>.json
  scripts/build.sh HostedTests-<SDK>HostedTests iOS
  ```

  `scripts/repo.sh decrypt` reads the passphrase from the `secrets_passphrase`
  environment variable.
- Jobs that need secrets can't run on pull requests from forks. Guard them like
  the other jobs that use secrets.

## Keychain hygiene

Every test target shares the host app's keychain access group, and the
simulator keeps keychain items between runs. In tests that use the keychain:

- Use service and account names that no other suite uses, for example by
  including the SDK name and a UUID.
- Delete the items the test adds, also when it fails, for example in
  `tearDown` or with `addTeardownBlock`.
- Don't assume the keychain starts empty.

## When to add another host app

Add another blank host target only when an SDK needs host settings that would
change other SDKs' tests, for example:

- Info.plist keys that change SDK behavior, such as Messaging's
  `FirebaseAppDelegateProxyEnabled`.
- Entitlements or capabilities that other SDKs must not have.

Copy `FirebaseTestHost` (its source folder and target), give it its own bundle
identifier, and set the SDK test target's **Host Application** to it.
