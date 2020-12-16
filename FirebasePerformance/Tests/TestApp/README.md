# [Firebase Performance](https://firebase.google.com/docs/perf-mon/get-started-ios) Development App

## Setup

For Prod environment, create a [Firebase project]((https://console.firebase.google.com/)) with bundle ID `com.google.FIRPerfTestApp`. Download and store the `GoogleService-Info.plist` under [Plists/Prod/FIRPerfTestApp/](./Plists/Prod/FIRPerfTestApp/). This should be sufficient for most scenarios.

For Autopush environment, create a [Firebase project]((https://console.firebase.google.com/)) with bundle ID `com.google.FIRPerfTestAppAutopush`. Download and store the
`GoogleService-Info.plist` under [Plists/Autopush/FIRPerfTestAppAutopush/](./Plists/Autopush/FIRPerfTestAppAutopush/). The events generated for the Autopush environment will not be available on the console outside of Google as these are processed on our staging servers.


## Build

### Generate project for Prod environment from [FirebasePerformance](../../)

- `sh generate_project.sh -e "prod"`

### Generate project for Autopush environment from [FirebasePerformance](../../)

- `sh generate_project.sh` (or) `sh generate_project.sh -e "autopush"`

## Run

- Select `FirebasePerformance-TestApp` target and device to run the App
