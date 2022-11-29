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

/// Provides the APIs to access Settings and their configuration values
protocol SettingsProtocol {
  func isCacheExpired(currentTime: Date) -> Bool
  func fetchAndCacheSettings(currentTime: Date)
  var sessionsEnabled: Bool { get }
  var samplingRate: Double { get }
  var sessionTimeout: TimeInterval { get }
}

class Settings: SettingsProtocol {
  private static let cacheDurationSecondsDefault: TimeInterval = 60 * 60
  private static let flagSessionsEnabled = "sessions_enabled"
  private static let flagSamplingRate = "sampling_rate"
  private static let flagSessionTimeout = "session_timeout"
  private static let flagCacheDuration = "cache_duration"
  private let appInfo: ApplicationInfoProtocol
  private let cache: SettingsCacheClient
  private let downloader: SettingsDownloadClient

  var sessionsEnabled: Bool {
    guard let enabled = cache.cacheContent?[Settings.flagSessionsEnabled] as? Bool else {
      return true
    }
    return enabled
  }

  var samplingRate: Double {
    guard let rate = cache.cacheContent?[Settings.flagSamplingRate] as? Double else {
      return 1.0
    }
    return rate
  }

  var sessionTimeout: TimeInterval {
    guard let timeout = cache.cacheContent?[Settings.flagSessionTimeout] as? Double else {
      return 30 * 60
    }
    return timeout
  }

  private var cacheDurationSeconds: TimeInterval {
    guard let duration = cache.cacheContent?[Settings.flagCacheDuration] as? Double else {
      return Settings.cacheDurationSecondsDefault
    }
    return duration
  }

  init(appInfo: ApplicationInfoProtocol,
       cache: SettingsCacheClient = SettingsCache(),
       downloader: SettingsDownloadClient = SettingsDownloader()) {
    self.cache = cache
    self.appInfo = appInfo
    self.downloader = downloader
  }
  
  func fetchAndCacheSettings(currentTime: Date) {
    guard !isCacheExpired(currentTime: currentTime) else {
      return
    }
    
    downloader.fetch(appInfo: self.appInfo) { result in
      switch result {
      case .success(let dictionary):
        // TODO
      case .failure(let error):
        Logger.logError("[Settings] Fetch failed with error: \(error)")
      }
    }
  }

  func isCacheExpired(currentTime: Date) -> Bool {
    guard cache.cacheContent != nil else {
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
    if currentTime.timeIntervalSince(cacheKey.createdAt) > cacheDurationSeconds {
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
