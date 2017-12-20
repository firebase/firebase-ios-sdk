# Unreleased

# 2017-11-30 -- v4.0.12 -- M20.2
- [fixed] Removed `FIR_SWIFT_NAME` macro, replaced with proper `NS_SWIFT_NAME`.

# 2017-11-14 -- v4.0.11 -- M20.1
- [feature] Added `-FIRLoggerForceSTDERR` launch argument flag to force STDERR
  output for all Firebase logging

# 2017-08-25 -- v4.0.6 -- M18.1
- [changed] Removed unused method

# 2017-08-09 -- v4.0.5 -- M18.0
- [changed] Log an error for an incorrectly configured bundle ID instead of an info
  message.

# 2017-07-12 -- v4.0.4 -- M17.4
- [changed] Switched to using the https://cocoapods.org/pods/nanopb pod instead of
  linking nanopb in (preventing linker conflicts).

# 2017-06-06 -- v4.0.1 -- M17.1
- [fixed] Improved diagnostic messages for Swift

# 2017-05-17 -- v4.0.0 -- M17
- [changed] Update FIROptions to have a simpler constructor and mutable properties
- [feature] Swift naming update, FIR prefix dropped
- [changed] Internal cleanup for open source release
