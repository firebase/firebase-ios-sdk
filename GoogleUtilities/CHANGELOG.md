# Unreleased

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
