{
    "authors": "Google, Inc.",
    "cocoapods_version": ">= 1.10.2",
    "default_subspecs": "AdIdSupport",
    "dependencies": {
        "GoogleUtilities/AppDelegateSwizzler": "~> 7.7",
        "GoogleUtilities/MethodSwizzler": "~> 7.7",
        "GoogleUtilities/NSData+zlib": "~> 7.7",
        "GoogleUtilities/Network": "~> 7.7",
        "nanopb": [ ">= 2.30908.0", "< 2.30910.0" ]
    },
    "description": "Measurement methods that are shared between Google libraries. This pod does not expose any headers and isn't intended for direct use, but rather as a dependency of some Google libraries.",
    "frameworks": [
        "StoreKit"
    ],
    "homepage": "https://developers.google.com/ios",
    "libraries": [
        "c++",
        "sqlite3",
        "z"
    ],
    "license": {
        "text": "Copyright 2022 Google",
        "type": "Copyright"
    },
    "name": "GoogleAppMeasurement",
    "platforms": {
        "ios": "10.0",
        "osx": "10.12",
        "tvos": "12.0"
    },
    "source": {
        "http": "https://dl.google.com/firebase/ios/analytics/4069635ec3f26ac6/GoogleAppMeasurement-9.1.0.tar.gz"
    },
    "subspecs": [
        {
            "name": "AdIdSupport",
            "dependencies": {
                "GoogleAppMeasurement/WithoutAdIdSupport": "9.1.0"
            },
            "vendored_frameworks": [
                "Frameworks/GoogleAppMeasurementIdentitySupport.xcframework"
            ]
        },
        {
            "name": "WithoutAdIdSupport",
            "vendored_frameworks": [
                "Frameworks/GoogleAppMeasurement.xcframework"
            ]
        }
    ],
    "summary": "Shared measurement methods for Google libraries. Not intended for direct use.",
    "version": "9.1.0"
}
