# [Firebase Performance](https://firebase.google.com/docs/perf-mon/get-started-ios) Development App

## Setup

Download the `GoogleService-Info.plist` file from [Firebase Console](https://console.firebase.google.com/)
(for whatever Firebase project you have or want to integrate the `dev-app`). 

For Prod environment, store the `GoogleService-Info.plist` under [Plists/Prod/FIRPerfTestApp/](./Plists/Prod/FIRPerfTestApp/). This should be sufficient for most scenarios. 

For Autopush environment, store the
`GoogleService-Info.plist` under [Plists/Autopush/FIRPerfTestAppAutopush/](./Plists/Autopush/FIRPerfTestAppAutopush/).


## Build

### Generate project for Prod environment from [FirebasePerformance](../../)

- `sh generate_project.sh -e "prod"`

### Generate project for Autopush environment from [FirebasePerformance](../../)

- `sh generate_project.sh` (or) `sh generate_project.sh -e "autopush"`

## Run

- Select `FirebasePerformance-TestApp` target and device to run the App
