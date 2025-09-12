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
internal import FirebaseCoreInternal

/// Extends ApplicationInfoProtocol to string-format a combined appDisplayVersion and
/// appBuildVersion
extension ApplicationInfoProtocol {
  var synthesizedVersion: String { return "\(appDisplayVersion) (\(appBuildVersion))" }
}

final class RemoteSettings: SettingsProvider, Sendable {
  private static let flagSessionsEnabled = "sessions_enabled"
  private static let flagSamplingRate = "sampling_rate"
  private static let flagSessionTimeout = "session_timeout_seconds"
  private static let flagSessionsCache = "app_quality"
  private let appInfo: ApplicationInfoProtocol
  private let downloader: SettingsDownloadClient
  private let cache: UnfairLock<SettingsCacheClient>

  private var sessionsCache: [String: Any] {
    cache.withLock { cache in
      cache.cacheContent[RemoteSettings.flagSessionsCache] as? [String: Any] ?? [:]
    }
  }

  init(appInfo: ApplicationInfoProtocol,
       downloader: SettingsDownloadClient,
       cache: SettingsCacheClient = SettingsCache()) {
    self.appInfo = appInfo
    self.cache = UnfairLock(cache)
    self.downloader = downloader
  }

  private func fetchAndCacheSettings(currentTime: Date) {
    let shouldFetch = cache.withLock { cache in
      // Only fetch if cache is expired, otherwise do nothing
      guard cache.isExpired(for: appInfo, time: currentTime) else {
        Logger.logDebug("[Settings] Cache is not expired, no fetch will be made.")
        return false
      }
      return true
    }

    if shouldFetch {
      downloader.fetch { result in

        switch result {
        case let .success(dictionary):
          self.cache.withLock { cache in
            // Saves all newly fetched Settings to cache
            cache.cacheContent = dictionary
            // Saves a "cache-key" which carries TTL metadata about current cache
            cache.cacheKey = CacheKey(
              createdAt: currentTime,
              googleAppID: self.appInfo.appID,
              appVersion: self.appInfo.synthesizedVersion
            )
          }
        case let .failure(error):
          Logger.logError("[Settings] Fetching newest settings failed with error: \(error)")
        }
      }
    }
  }
}

typealias RemoteSettingsConfigurations = RemoteSettings
extension RemoteSettingsConfigurations {
  var sessionsEnabled: Bool? {
    return sessionsCache[RemoteSettings.flagSessionsEnabled] as? Bool
  }

  var samplingRate: Double? {
    return sessionsCache[RemoteSettings.flagSamplingRate] as? Double
  }

  var sessionTimeout: TimeInterval? {
    return sessionsCache[RemoteSettings.flagSessionTimeout] as? Double
  }
}

typealias RemoteSettingsProvider = RemoteSettings
extension RemoteSettingsConfigurations {
  func updateSettings(currentTime: Date) {
    fetchAndCacheSettings(currentTime: currentTime)
  }

  func updateSettings() {
    updateSettings(currentTime: Date())
  }

  func isSettingsStale() -> Bool {
    cache.withLock { cache in
      cache.isExpired(for: appInfo, time: Date())
    }
  }
}
