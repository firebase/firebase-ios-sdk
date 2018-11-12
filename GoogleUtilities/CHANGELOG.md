# Unreleased
- Fixed an issue where GoogleUtilities would leak non-background URL sessions.
  (#2061)

# 5.3.4
- Fixed a crash caused by unprotected access to sessions in
  `GULNetworkURLSession` (#1964).

# 5.3.3
- Fixed an issue where GoogleUtilities would leak instances of `NSURLSession`.
  (#1917)
