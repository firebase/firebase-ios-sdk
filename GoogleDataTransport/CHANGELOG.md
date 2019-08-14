# v1.1.2
- Add initial support for iOS 13.
- Add initial support for Catalyst.

# v1.1.1
- Fix a crash in GDTUploadPackage and GDTStorage.
https://github.com/firebase/firebase-ios-sdk/issues/3547

# v1.1.0
- Remove almost all NSAsserts and NSCAsserts for a better development
experience. Fixes https://github.com/firebase/firebase-ios-sdk/issues/3530

# v1.0.0
- Initial Release--for Google-use only. This library is the foundation of a
network transport layer that focuses on transparently and respectfully
transporting data that is collected for purposes that vary depending on the
adopting SDK. Primarily, we seek to reduce Firebase's impact on binary size,
mobile data consumption, and battery use for end users by aggregating collected
data and transporting it under ideal conditions. Users should expect to see an
increase in the number of Cocoapods/frameworks/libraries, but a decrease in
binary size over time as our codebase becomes more modularized.
