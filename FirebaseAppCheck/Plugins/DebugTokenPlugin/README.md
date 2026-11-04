# Firebase App Check Debug Token Plugin

`FirebaseAppCheckDebugTokenPlugin` embeds a Firebase App Check debug token in
Debug builds of an app so that `AppCheckDebugProvider` can use it on physical
devices. On simulators and macOS, the debug provider reads the token directly
from the Firebase CLI configuration file, so the plugin isn't needed there.

> [!WARNING]
> A debug token allows access to your Firebase backend resources, and anyone
> with a build that embeds a token can extract it. Don't distribute builds that
> embed a debug token, and revoke tokens that you no longer need.

## How it works

Before every build, the plugin:

1. Reads `GOOGLE_APP_ID` from the target's `GoogleService-Info.plist`.
2. Looks up the debug token for that app ID in the Firebase CLI configuration
   file: `$XDG_CONFIG_HOME/configstore/firebase-appcheck.json` when
   `XDG_CONFIG_HOME` is set, otherwise
   `~/.config/configstore/firebase-appcheck.json`.
3. Generates `AppCheckDebugToken.generated.swift`, which defines the
   `FIRAppCheckInjectedDebugToken` class inside `#if DEBUG`, so Release builds
   don't contain the token.

Only the token for the target's app ID is embedded. If no token is found, the
generated class contains no tokens and the debug provider falls back to its
other token sources. The file is rewritten only when its contents change, so a
rotated token is picked up by the next build without triggering unnecessary
recompilation.

## Usage

### Swift package targets

```swift
.executableTarget(
  name: "MyApp",
  dependencies: [.product(name: "FirebaseAppCheck", package: "firebase-ios-sdk")],
  plugins: [
    .plugin(name: "FirebaseAppCheckDebugTokenPlugin", package: "firebase-ios-sdk"),
  ]
)
```

### Xcode app targets

In the app target's **Build Phases**, add `FirebaseAppCheckDebugTokenPlugin`
to **Run Build Tool Plug-ins**. Apply the plugin to the app target only:
applying it to more than one target in the same app defines the
`FIRAppCheckInjectedDebugToken` class more than once.

### Run Script build phase

If you can't use the plugin, add a **Run Script** build phase before **Compile
Sources** that runs the script from the Firebase package checkout:

```sh
/bin/sh "${BUILD_DIR%/Build/*}/SourcePackages/checkouts/firebase-ios-sdk/FirebaseAppCheck/Scripts/inject_debug_token.sh"
```

- Add `$(DERIVED_FILE_DIR)/AppCheckDebugToken.generated.swift` to the phase's
  **Output Files**.
- Uncheck **Based on dependency analysis** so that the script runs on every
  build and picks up token changes.
- If `ENABLE_USER_SCRIPT_SANDBOXING` is enabled for the target, the script can
  only read declared input files. Either set it to `NO`, or add
  `$(HOME)/.config/configstore/firebase-appcheck.json` and your
  `GoogleService-Info.plist` to the phase's **Input Files** (the configuration
  file must then exist).

The script only embeds a token in build configurations whose name contains
`Debug`.
