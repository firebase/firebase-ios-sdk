# Unreleased
- Update comments in `GULAppDelegateSwizzler` (#4518)

# 6.4.0
- Add function to gul secure encoding to encode multiple classes. (#4282)
- Add heartbeat feature. (#4098)
- Support UISceneDelegate changes in Auth. (#4380)

# 6.3.1
- Fix GULMutableDictionary keyed subscript methods. (#3882)
- Update Networking to receive data for POST requests. (#3940)
- Fix crash in GULLogBasic. (#3928)

# 6.3.0
- GULSecureCoding introduced. (#3707)
- Mark unused variables. (#3854)

# 6.2.5
- Remove test-only method and update tests to include Catalyst. (#3544)

# 6.2.4
- Fix `GULObjectSwizzler` dealloc thread-safety. (#3300, #3183)

# 6.2.3
- Revert "Fix `GULMutableDictionary` thread-safety." (#3322)

# 6.2.2
- Add explicit Foundation import for headers.
- Fix headers import. (#3277)
- Fix README. (#3305)
- Fix `GULMutableDictionary` thread-safety. (#3322)

# 6.2.1
- Fix Xcode 11 build warning. (#3133)

# 6.2.0
- Stop conditional compilation for GoogleUtilities testing. (#3058)

# 6.1.0
- Added `GULAppDelegateSwizzler` macOS support. (#2911)

# 6.0.0
- GULAppDelegateSwizzler - proxy APNS methods separately. (#2835)
- Cocoapods 1.7.0 multiproject support. (#2751)
- Bump minimium iOS version to iOS 8. (#2876)

# 5.7.0
- Restore to 5.5.0 tag after increased App Store warnings. (#2807)

# 5.6.0
- `GULAppDelegateSwizzler`: support of remote notification methods. (#2698)
- `GULAppDelegateSwizzler`: tvOS support. (#2698)

# 5.5.0
- Revert 5.4.x changes restoring 5.3.7 version.

# 5.4.1
- Fix GULResetLogger API breakage. (#2551)

# 5.4.0
- Update GULLogger to use os_log instead of asl_log on iOS 9 and later. (#2374, #2504)

# 5.3.7
- Fixed `pod lib lint GoogleUtilities.podspec --use-libraries` regression. (#2130)
- Fixed macOS conditional check in UserDefaults. (#2245)
- Migrate to clang-format 8.0.0. (#2222)

# 5.3.6
- Fix nullability issues. (#2079)

# 5.3.5
- Fixed an issue where GoogleUtilities would leak non-background URL sessions.
  (#2061)
- Fixed a crash caused due to `NSURLConnection` delegates being wrapped in an
  `NSProxy`. (#1936)

# 5.3.4
- Fixed a crash caused by unprotected access to sessions in
  `GULNetworkURLSession`. (#1964)

# 5.3.3
- Fixed an issue where GoogleUtilities would leak instances of `NSURLSession`.
  (#1917)
