{
    "authors": "Google, Inc.",
    "cocoapods_version": ">= 1.10.0",
    "default_subspecs": "AdIdSupport",
    "dependencies": {
        "FirebaseCore": "~> 9.0",
        "FirebaseInstallations": "~> 9.0",
        "GoogleUtilities/AppDelegateSwizzler": "~> 7.7",
        "GoogleUtilities/MethodSwizzler": "~> 7.7",
        "GoogleUtilities/NSData+zlib": "~> 7.7",
        "GoogleUtilities/Network": "~> 7.7",
        "nanopb": [ ">= 2.30908.0", "< 2.30910.0" ]
    },
    "description": "Firebase Analytics is a free, out-of-the-box analytics solution that inspires actionable insights based on app usage and user engagement.",
    "frameworks": [
        "StoreKit"
    ],
    "homepage": "https://firebase.google.com/features/analytics/",
    "libraries": [
        "c++",
        "sqlite3",
        "z"
    ],
    "license": {
        "text": "Copyright 2022 Google",
        "type": "Copyright"
    },
    "name": "FirebaseAnalytics",
    "platforms": {
        "ios": "10.0",
        "osx": "10.12",
        "tvos": "12.0"
    },
    "source": {
        "http": "https://dl.google.com/firebase/ios/analytics/8e504e0b8788faff/FirebaseAnalytics-9.1.0.tar.gz"
    },
    "subspecs": [
        {
            "name": "AdIdSupport",
            "dependencies": {
                "GoogleAppMeasurement": "9.1.0"
            },
            "vendored_frameworks": [
                "Frameworks/FirebaseAnalytics.xcframework"
            ]
        },
        {
            "name": "WithoutAdIdSupport",
            "dependencies": {
                "GoogleAppMeasurement/WithoutAdIdSupport": "9.1.0"
            },
            "vendored_frameworks": [
                "Frameworks/FirebaseAnalytics.xcframework"
            ]
        }
    ],
    "summary": "Firebase Analytics for iOS",

    "swift_version" : "5.3",
    "version": "9.1.0"
}
