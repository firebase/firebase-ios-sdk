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