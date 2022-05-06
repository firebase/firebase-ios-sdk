# v1.7.0
- Internal headers removed from public headers. (#6442)

# v1.6.0
- Add logging for Swift Package Manager.

# v1.2.3
- Remove usage of memcpy and convert calls from malloc to calloc.

# v1.2.2
- Fixed a bug that would manifest if a proto ended up being > 16,320 bytes.
- Now checks the result of malloc. (#4872)

# v1.2.0
- Added basic watchOS support.

# v1.1.2
- Switch the backend for diagnostics to FLL from CCT.

# v1.1.1
- Updated nanopb from 0.3.9.2 to 0.3.9.3.

# v1.1.0
- Updates GDT dependency to GDTCOR prefixed version.

# v1.0.0
Initial Release--for Google use only. This library collects diagnostics and
usage data for internal use by Firebase. Data gathered by this library will
only be uploaded at most once every 24 hours whilst on mobile data, and more
frequently on wifi if it's available. This library has been integrated as a
weak dependency and can be safely removed by using a non-Cocoapods distribution
method. You can also use the Firebase global data collection flag to opt-out of
collecting this usage data.
