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
