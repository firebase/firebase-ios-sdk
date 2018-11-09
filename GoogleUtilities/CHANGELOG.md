# Unreleased

- Fixed a crash caused due to `NSURLConnection` delegates being wrapped in a
  `NSProxy`. (#1936)

# 5.3.4
- Fixed a crash caused by unprotected access to sessions in
  `GULNetworkURLSession` (#1964).

# 5.3.3
- Fixed an issue where GoogleUtilities would leak instances of `NSURLSession`.
  (#1917)
