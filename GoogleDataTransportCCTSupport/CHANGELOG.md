# v2.0.1
- Don't attempt to make NSData out of a nil file URL. (#5088)

# v2.0.0
- Adds a sentinel value to GDTCOREvent's custom params to signal collection
of current network info to be associated with some event. This is required
for Firebase Performance Monitoring in the future.

# v1.4.1
- Fixed a bug that would manifest if a proto ended up being > 16,320 bytes.
- Fix an Xcode 11.4 analyze error. (#4863)
- Now checks the result of malloc. (#4871)

# v1.4.0
- Added the CSH backend and consolidated the CCT, FLL, and CSH backends.

# v1.3.1
- Adds compression to requests to CCT.
- Requests going to the FLL backend will only use compressed data when smaller.
- Added extensive debug logging that can be turned on by changing
GDT_VERBOSE_LOGGING to 1 in GDTCORConsoleLogger.h.

# v1.3.0
- Implemented initial support for watchOS.

# v1.2.3
- Fixed issues discovered by tsan in tests.
- Add the request time to the outgoing proto.

# v1.2.2
- Added redirect response handling to FLL.
- Only use gzipped data when it's smaller than the original and successful.

# v1.2.1
- Fixes sanitizer issues and runtime errors. (#4039, #4027)
- Fixes a threading issue with ivar access in GDTCORUploadCoordinator. (#4019)

# v1.2.0
- Updates GDT dependency to improve backgrounding logic.
- Reduces requests for background task creation. (#3893)
- Fix unbalanced background task creation in GDTCCTUploader. (#3838)
- Fixes a nil argument being passed to GDTCCTEncodeString. (#3893)

# v1.1.0
- Updates GDT dependency to GDTCOR prefixed version.

# v1.0.4
- Balances background task creation with background task ending. (#3759)

# v1.0.3
- Remove all NSAsserts in favor of GDTCORAssert.

# v1.0.2
- More safely handle backgrounding.

# v1.0.1
- Removed unused fields from firebasecore.proto.

# v1.0.0
- Initial Release--for Google-use only. This library adds support for the CCT
Google backend.
