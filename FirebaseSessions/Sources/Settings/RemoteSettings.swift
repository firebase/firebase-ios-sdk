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

/// Extends ApplicationInfoProtocol to string-format a combined appDisplayVersion and appBuildVersion
extension ApplicationInfoProtocol {
  var synthesizedVersion: String { return "\(appDisplayVersion) (\(appBuildVersion))" }
}

class RemoteSettings: SettingsProvider {
  private static let cacheDurationSecondsDefault: TimeInterval = 60 * 60
  private static let flagSessionsEnabled = "sessions_enabled"
  private static let flagSamplingRate = "sampling_rate"
  private static let flagSessionTimeout = "session_timeout_seconds"
  private static let flagCacheDuration = "cache_duration"
  private static let flagSessionsCache = "app_quality"
  private let appInfo: ApplicationInfoProtocol
  private let downloader: SettingsDownloadClient
  private var cache: SettingsCacheClient

  private var cacheDurationSeconds: TimeInterval {
    guard let duration = cache.cacheContent[RemoteSettings.flagCacheDuration] as? Double else {
      return RemoteSettings.cacheDurationSecondsDefault
    }
    return duration
  }

  private var sessionsCache: [String: Any] {
    return cache.cacheContent[RemoteSettings.flagSessionsCache] as? [String: Any] ?? [:]
  }

  init(appInfo: ApplicationInfoProtocol,
       downloader: SettingsDownloadClient,
       cache: SettingsCacheClient = SettingsCache()) {
    self.appInfo = appInfo
    self.cache = cache
    self.downloader = downloader
  }

  private func fetchAndCacheSettings(currentTime: Date) {
    // Only fetch if cache is expired, otherwise do nothing
    guard isCacheExpired(time: currentTime) else {
      Logger.logDebug("[Settings] Cache is not expired, no fetch will be made.")
      return
    }

    downloader.fetch { result in
      switch result {
      case let .success(dictionary):
        // Saves all newly fetched Settings to cache
        self.cache.cacheContent = dictionary
        // Saves a "cache-key" which carries TTL metadata about current cache
        self.cache.cacheKey = CacheKey(
          createdAt: currentTime,
          googleAppID: self.appInfo.appID,
          appVersion: self.appInfo.synthesizedVersion
        )
      case let .failure(error):
        Logger.logError("[Settings] Fetching newest settings failed with error: \(error)")
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
    return isCacheExpired(time: Date())
  }

  private func isCacheExpired(time: Date) -> Bool {
    guard !cache.cacheContent.isEmpty else {
      cache.removeCache()
      return true
    }
    guard let cacheKey = cache.cacheKey else {
      Logger.logError("[Settings] Could not load settings cache key")
      cache.removeCache()
      return true
    }
    guard cacheKey.googleAppID == appInfo.appID else {
      Logger
        .logDebug("[Settings] Cache expired because Google App ID changed")
      cache.removeCache()
      return true
    }
    if time.timeIntervalSince(cacheKey.createdAt) > cacheDurationSeconds {
      Logger.logDebug("[Settings] Cache TTL expired")
      return true
    }
    if appInfo.synthesizedVersion != cacheKey.appVersion {
      Logger.logDebug("[Settings] Cache expired because app version changed")
      return true
    }
    return false
  }
}
