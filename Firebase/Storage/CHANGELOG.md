# v2.1.0
- [added] Added 'md5Hash' to FIRStorageMetadata.

# v2.0.2
- [changed] Custom FIRStorageMetadata can now be cleared by setting individual properties to 'nil'.

# v2.0.1
- [fixed] Fixed crash in FIRStorageDownloadTask that was caused by invoking callbacks that where no longer active.
- [changed] Added 'size' to the NSDictionary representation of FIRStorageMetadata.

# v2.0.0
- [changed] Initial Open Source release.

# v1.0.6

- [fixed] Fixed crash when user-provided callbacks were nil.
- [changed] Improved upload performance under spotty connectivity.

# v1.0.5

- [fixed] Snapshot data is now always from the requested snapshot, rather than
  the most recent snapshot.
- [fixed] Fixed an issue with downloads that were not properly pausing.

# v1.0.4

- [fixed] Fixed an issue causing us to not respect the developer-specified
  timeouts for initial up- and download requests.
- [fixed] Fixed uploading issues with filenames that contain the '+' character.
