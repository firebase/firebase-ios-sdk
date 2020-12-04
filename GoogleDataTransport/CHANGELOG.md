# v8.1.0
- Expose upload URLs which FirebasePerformance will depend upon.
- Fix out-of-memory crash for a big amount of pending events. (#6995)

# v8.0.1
- Remove `GCC_TREAT_WARNINGS_AS_ERRORS` from the podspec.
- Reduce pre-main startup time footprint. (#6855)

# v8.0.0
- Source restructuring to limit the public API surface.

# v7.5.1
- Fix deprecation warning for iOS 12.0 and higher projects. (#6682)

# v7.5.0
- Legacy pre Xcode 10 compatibility checks removed. (#6486)
- `GDTCORDirectorySizeTracker` crash fixed. (#6540)

# v7.4.0
- Limit disk space consumed by GoogleDataTransport to store events. (#6365)
- Fix `GDTTransformer` background task handling.  (#6258)

# v7.1.1
- Use `NSTimeZone` instead of `CFTimeZone` to get time zone offset respecting daylight. (#6246)

# v7.1.0
- Device uptime calculation fixes. (#6102)

# v7.0.0
- Storage has been completely reimplemented to a flat-file system. It
is not backwards compatible with previously saved events.
- Prioritizers, data futures, and upload packages have been removed.
- Consolidated GoogleDataTransportCCTSupport with GoogleDataTransport. Starting
with this version, GoogleDataTransportCCTSupport should no longer be linked.
- `GDTCORFlatFileStorage`: keep not expired events when expired batch removed. (#6010)

# v6.2.1
- Stopped GDTCORUploadCoordinator from blocking main thread. (#5707, #5708)

# v6.2.0
- Added an API for arbitrary data persistence on storage instances.
- Added an API for fetching storage instances specific to a target.

# v6.1.1
- Fixes writing event counts in a directory that doesn't yet exist. (#5549)

# v6.1.0
- watchOS extension and independent apps now supported. (#4292)
- iOS extensions better supported.
- GDTCORReachability will lazily initialize to address library loading hang. (#5463)

# v6.0.0
- Internal refactor to change storage to a protocol.

# v5.1.1
- Remove usage of memcpy and convert calls from malloc to calloc.
- Fixes a race condition likely to occur when removing events.

# v5.1.0
- Stops creation of an event with a nil fileURL. (#5088)
- Adds API to consolidate make NSSecureCoding related calls.
- Better Catalyst support in testing.
- GDTCOREvent is moved to an app cache relative path model.
- Better debug logging.

# v5.0.0
- Refactors some APIs to fix passing of data from event generation to storage.

# v4.0.1
- Fixes missing a dispatch_sync and on-queue work in appWillTerminate of storage. (#4546)

# v4.0.0
- Internal restructuring to support a single class implementing several backends.

# v3.3.1
- Added extensive debug logging that can be turned on by changing
GDT_VERBOSE_LOGGING to 1 in GDTCORConsoleLogger.h.

# v3.3.0
- Implemented initial support for watchOS.

# v3.2.0
- Expose the library version with a #define to a const string var.

# v3.1.0
- Fixes additional sanitizer issues and runtime errors.

# v3.0.1
- Fixes sanitizer issues and runtime errors. (#4039, #4027)

# v3.0.0
- Changes backgrounding logic to reduce background usage and properly complete
all tasks. (#3893)
- Fix Catalyst define checks. (#3695)
- Fix ubsan issues in GDT (#3910)
- Add support for FLL. (#3867)

# v2.0.0
- Change/rename all classes and references from GDT to GDTCOR. (#3729)

# v1.2.0
- Removes all NSAsserts in favor of custom asserts. (#3747)

# v1.1.3
- Wrap decoding in GDTCORUploadCoordinator in a try catch. (#3676)

# v1.1.2
- Add initial support for iOS 13.
- Add initial support for Catalyst.
- Backgrounding in GDTCORStorage is fixed. (#3623 and #3625)

# v1.1.1
- Fixes a crash in GDTCORUploadPackage and GDTCORStorage. (#3547)

# v1.1.0
- Remove almost all NSAsserts and NSCAsserts for a better development
experience. (#3530)

# v1.0.0
- Initial Release--for Google-use only. This library is the foundation of a
network transport layer that focuses on transparently and respectfully
transporting data that is collected for purposes that vary depending on the
adopting SDK. Primarily, we seek to reduce Firebase's impact on binary size,
mobile data consumption, and battery use for end users by aggregating collected
data and transporting it under ideal conditions. Users should expect to see an
increase in the number of Cocoapods/frameworks/libraries, but a decrease in
binary size over time as our codebase becomes more modularized.
