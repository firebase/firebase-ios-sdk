# v4.1.0
- Added [multi-resource](https://firebase.google.com/docs/database/usage/sharding) support to the database SDK.

# v4.0.3
- [fixed] Fixed a regression in v4.0.2 that affected the storage location of the offline persistent cache. This caused v4.0.2 to not see data written with previous versions.
- [fixed] Fixed a crash in `FIRApp deleteApp` for apps that did not have active database instances.

# v4.0.2
- [fixed] Retrieving a Database instance for a specific `FirebaseApp` no longer returns a stale instance if that app was deleted.
- [changed] Added message about bandwidth usage in error for queries without indexes.

# v4.0.1
- [changed] We now purge the local cache if we can't load from it.
- [fixed] Removed implicit number type conversion for some integers that were represented as doubles after round-tripping through the server.
- [fixed] Fixed crash for messages that were send to closed WebSocket connections.

# v4.0.0
- [changed] Initial Open Source release.

# v3.1.2

- [changed] Removed unnecessary _CodeSignature folder to address compiler
  warning for "Failed to parse Mach-O: Reached end of file while looking for:
  uint32_t".
- [changed] Log a message when an observeEvent call is rejected due to security
  rules.

# v3.1.1

- [changed] Unified logging format.

# v3.1.0

- [feature] Reintroduced the persistenceCacheSizeBytes setting (previously
  available in the 2.x SDK) to control the disk size of Firebase's offline
  cache.
- [fixed] Use of the updateChildValues() method now only cancels transactions
  that are directly included in the updated paths (not transactions in adjacent
  paths). For example, an update at /move for a child node walk will cancel
  transactions at /, /move, and /move/walk and in any child nodes under
  /move/walk. But, it will no longer cancel transactions at sibling nodes,
  such as /move/run.

# v3.0.3

- [fixed] Fixed an issue causing transactions to fail if executed before the
  SDK connects to the Firebase Database backend.
- [fixed] Fixed a race condition where doing a transaction or adding an event
  observer immediately after connecting to the Firebase Database backend could
  result in completion blocks for other operations not getting executed.
- [fixed] Fixed an issue affecting apps using offline disk persistence where
  large integer values could lose precision after an app restart.
