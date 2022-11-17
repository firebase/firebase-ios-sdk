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

extension URL {
  func appendingCompatible(path: String) -> URL {
    #if (os(iOS) && !targetEnvironment(macCatalyst)) || os(tvOS)
      if #available(iOS 16.0, tvOS 16.0, *) {
        return appending(path: path)
      }
    #endif
    return appendingPathComponent(path)
  }
}

struct CacheKey: Codable {
  var createdAt: Date
  var googleAppID: String
  var appVersion: String
}

protocol SettingsCacheClient {
  /// Returns in-memory cache content in O(1) time
  var cacheContent: [String: Any]? { get }
  /// Returns in-memory cache key, no performance guarantee because conversion depends on size of CacheKey
  var cacheKey: CacheKey? { get }
  func removeCache()
}

class SettingsCache: SettingsCacheClient {
  private static let settingsVersion: Int = 1
  private static let content: String = "settings"
  private static let key: String = "cache-key"
  /// UserDefaults holds values in memory, making access O(1) and synchronous within the app, while abstracting away async disk IO.
  private let cache: UserDefaults = .standard

  init() {}

  /// Converting to dictionary is O(1) because object conversion is O(1)
  var cacheContent: [String: Any]? {
    return cache.dictionary(forKey: SettingsCache.content)
  }

  /// Casting to Codable from Data is O(n)
  var cacheKey: CacheKey? {
    if let data = cache.data(forKey: SettingsCache.key) {
      do {
        return try JSONDecoder().decode(CacheKey.self, from: data)
      } catch {
        Logger.logError("[Settings] Decoding CacheKey failed with error: \(error)")
      }
    }
    return nil
  }

  /// Removes stored cache
  func removeCache() {
    cache.set(nil, forKey: SettingsCache.content)
    cache.set(nil, forKey: SettingsCache.key)
  }
}
