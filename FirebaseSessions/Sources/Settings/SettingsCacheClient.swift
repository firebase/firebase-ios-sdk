//
// Copyright 2022 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation

// TODO: sendable (remove preconcurrency)
#if SWIFT_PACKAGE
  @preconcurrency internal import GoogleUtilities_UserDefaults
#else
  @preconcurrency internal import GoogleUtilities
#endif // SWIFT_PACKAGE

internal import FirebaseCoreInternal

/// CacheKey is like a "key" to a "safe". It provides necessary metadata about the current cache to
/// know if it should be expired.
struct CacheKey: Codable {
  var createdAt: Date
  var googleAppID: String
  var appVersion: String
}

/// SettingsCacheClient is responsible for accessing the cache that Settings are stored in.
protocol SettingsCacheClient: Sendable {
  // TODO: Add docs.
  func value<T>(forKey key: String) -> T?
  // TODO: Add docs.
  func updateContents(_ content: [String: Any])
  // TODO: Add docs.
  func updateMetadata(_ metadata: CacheKey)
  /// Removes all cache content and cache-key
  func removeCache()
  /// Returns whether the cache is expired for the given app info structure and time.
  func isExpired(for appInfo: ApplicationInfoProtocol, time: Date) -> Bool
}

// TODO: Update docs.
/// SettingsCache uses UserDefaults to store Settings on-disk, but also directly query UserDefaults
/// when accessing Settings values during run-time. This is because UserDefaults encapsulates both
/// in-memory and persisted-on-disk storage, allowing fast synchronous access in-app while hiding
/// away the complexity of managing persistence asynchronously.
final class SettingsCache: SettingsCacheClient {
  private static let cacheDurationSecondsDefault: TimeInterval = 60 * 60
  private static let flagCacheDuration = "cache_duration"
  private static let settingsVersion: Int = 1

  private enum UserDefaultsKeys {
    static let forContent = "firebase-sessions-settings"
    static let forCacheKey = "firebase-sessions-cache-key"
  }

  /// UserDefaults holds values in memory, making access O(1) and synchronous within the app, while
  /// abstracting away async disk IO.
  private let diskCache: GULUserDefaults = .standard()
  let namespace: String

  // TODO: populate from disk, read from namespaced contents
  private let memoryCache: UnfairLock<[String: Any]>
  private let memoryCacheKey: UnfairLock<CacheKey?>

  init(namespace: String) {
    self.namespace = namespace

    // Load the cache contents.
    if
      let storedContents = diskCache.object(forKey: UserDefaultsKeys.forContent) as? [String: Any],
      let storedNamespace = storedContents[namespace] as? [String: Any] {
      memoryCache = UnfairLock(storedNamespace)
    } else {
      // TODO: Should we clear diskCache?
      memoryCache = UnfairLock([:])
    }

    // TODO: Can I make this easier to read?
    // Load the cache key.
    if let data = diskCache.object(forKey: UserDefaultsKeys.forCacheKey) as? Data {
      do {
        let metadata = try JSONDecoder().decode(CacheKey.self, from: data)
        memoryCacheKey = UnfairLock(metadata)
      } catch {
        Logger.logError("[Settings] Decoding CacheKey failed with error: \(error)")
        // TODO: Should we clear diskCache?
        memoryCacheKey = UnfairLock(nil)
      }
    } else {
      // TODO: Should we clear diskCache?
      memoryCacheKey = UnfairLock(nil)
    }
  }

  // read
  // previous behavior:
  // if [String:Any] is nil, then bool
  // if [String:Any] is non-nil, but val missing, then bool
  func value<T>(forKey key: String) -> T? {
    memoryCache.withLock { memoryCache in
      memoryCache[key] as? T
    }
  }

  // write
  func updateContents(_ contents: [String: Any]) {
    // Write to in-memory cache.
    memoryCache.withLock { memoryCache in
      memoryCache = memoryCache
    }
    // Write to disk cache.
    let namespacedContents = [namespace: contents]
    diskCache.setObject(namespacedContents, forKey: UserDefaultsKeys.forContent)
  }

  // write
  func updateMetadata(_ metadata: CacheKey) {
    do {
      let encodedMetadata = try JSONEncoder().encode(metadata)
      // Write to in-memory cache.
      memoryCacheKey.withLock { memoryCacheKey in
        memoryCacheKey = metadata
      }
      // Write to disk cache.
      diskCache.setObject(encodedMetadata, forKey: UserDefaultsKeys.forCacheKey)
    } catch {
      Logger.logError("[Settings] Encoding CacheKey failed with error: \(error)")
    }
  }

  /// Removes stored cache
  func removeCache() {
    memoryCache.withLock { $0 = [:] }
    memoryCacheKey.withLock { $0 = nil }
    diskCache.setObject(nil, forKey: UserDefaultsKeys.forContent)
    diskCache.setObject(nil, forKey: UserDefaultsKeys.forCacheKey)
  }

  func isExpired(for appInfo: ApplicationInfoProtocol, time: Date) -> Bool {
    let isCacheEmpty = memoryCache.withLock(\.isEmpty)
    guard !isCacheEmpty else {
      removeCache()
      return true
    }

    let cacheKey = memoryCacheKey.withLock { $0 }
    guard let cacheKey else {
      Logger.logError("[Settings] Could not load settings cache key")
      removeCache()
      return true
    }
    guard cacheKey.googleAppID == appInfo.appID else {
      Logger
        .logDebug("[Settings] Cache expired because Google App ID changed")
      removeCache()
      return true
    }
    if time.timeIntervalSince(cacheKey.createdAt) > cacheDuration() {
      Logger.logDebug("[Settings] Cache TTL expired")
      return true
    }
    if appInfo.synthesizedVersion != cacheKey.appVersion {
      Logger.logDebug("[Settings] Cache expired because app version changed")
      return true
    }
    return false
  }

  // TODO: Is the refactor in isExpired above cause a behavior change from before?
  private func cacheDuration() -> TimeInterval {
    let cacheDuration = memoryCache.withLock { $0[Self.flagCacheDuration] }
    guard let duration = cacheDuration as? Double else {
      return Self.cacheDurationSecondsDefault
    }
    Logger.logDebug("[Settings] Cache duration: \(duration)")
    return duration
  }
}
