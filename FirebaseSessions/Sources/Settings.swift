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

protocol SettingsProtocol {
  func loadCache(googleAppID: String, currentTime: Date)
  var sessionsEnabled: Bool { get }
  var samplingRate: Double { get }
  var sessionTimeout: TimeInterval { get }
}

class Settings: SettingsProtocol {
  private static let cacheDurationSecondsDefault: TimeInterval = 60 * 60
  private let fileManager: SettingsFileManager
  private let appInfo: ApplicationInfoProtocol
  private let lock = NSLock()
  private var _settingsDictionary: [String: AnyObject]?
  private var isCacheKeyExpired: Bool
  struct CacheKey: Codable {
    var createdAt: Date
    var googleAppID: String
    var appVersion: String
  }

  var settingsDictionary: [String: AnyObject]? {
    objc_sync_enter(lock)
    defer { objc_sync_exit(lock) }
    return _settingsDictionary
  }

  var sessionsEnabled: Bool {
    guard let enabled = settingsDictionary?["sessions_enabled"]?.boolValue else {
      return true
    }
    return enabled
  }

  var samplingRate: Double {
    guard let rate = settingsDictionary?["sampling_rate"]?.doubleValue else {
      return 1
    }
    return rate
  }

  var sessionTimeout: TimeInterval {
    guard let timeout = settingsDictionary?["session_timeout"]?.doubleValue else {
      return 30 * 60
    }
    return timeout
  }

  var isCacheExpired: Bool {
    guard settingsDictionary != nil else {
      return true
    }
    return isCacheKeyExpired
  }

  private var cacheDurationSeconds: TimeInterval {
    guard let duration = settingsDictionary?["cache_duration"]?.doubleValue else {
      return Settings.cacheDurationSecondsDefault
    }
    return duration
  }

  init(fileManager: SettingsFileManager = SettingsFileManager(), appInfo: ApplicationInfoProtocol) {
    self.fileManager = fileManager
    isCacheKeyExpired = false
    self.appInfo = appInfo
  }

  func loadCache(googleAppID: String, currentTime: Date) {
    guard let cacheData = fileManager.data(contentsOf: fileManager.settingsCacheContentPath) else {
      Logger.logDebug("[Sessions:Settings] No settings were cached")
      return
    }
    guard let parsedDictionary = cacheData.dictionaryValue else {
      removeCache()
      return
    }
    do {
      objc_sync_enter(lock)
      defer { objc_sync_exit(lock) }
      _settingsDictionary = parsedDictionary
    }
    guard let cacheKeyData = fileManager.data(contentsOf: fileManager.settingsCacheKeyPath),
          let cacheKey = cacheKeyData.cacheKeyValue else {
      Logger.logError("[Sessions:Settings] Could not load settings cache key")
      removeCache()
      return
    }
    guard cacheKey.googleAppID == googleAppID else {
      Logger
        .logDebug("[Sessions:Settings] Invalidating settings cache because Google App ID changed")
      removeCache()
      return
    }
    if currentTime.timeIntervalSince(cacheKey.createdAt) > cacheDurationSeconds {
      Logger.logDebug("[Sessions:Settings] Settings TTL expired")
      do {
        objc_sync_enter(lock)
        defer { objc_sync_exit(lock) }
        isCacheKeyExpired = true
      }
    }
    if appInfo.synthesizedVersion != cacheKey.appVersion {
      Logger.logDebug("[Sessions:Settings] Settings expired because app version changed")
      do {
        objc_sync_enter(lock)
        defer { objc_sync_exit(lock) }
        isCacheKeyExpired = true
      }
    }
  }

  private func removeCache() {
    objc_sync_enter(lock)
    defer { objc_sync_exit(lock) }
    fileManager.removeCacheFiles()
    isCacheKeyExpired = true
    _settingsDictionary = nil
  }
}

extension ApplicationInfoProtocol {
  var synthesizedVersion: String { return "\(appDisplayVersion) (\(appBuildVersion))" }
}

private extension Data {
  var dictionaryValue: [String: AnyObject]? {
    do {
      let json = try JSONSerialization.jsonObject(with: self)
      if let dictionary = json as? [String: AnyObject] {
        return dictionary
      } else {
        Logger
          .logError("[Sessions:Settings] Could not cast JSON object as a Dictionary<String, Any>")
      }
    } catch {
      Logger.logError("[Sessions:Settings] Error: \(error)")
    }
    return nil
  }

  var cacheKeyValue: Settings.CacheKey? {
    do {
      let cacheKey = try JSONDecoder().decode(Settings.CacheKey.self, from: self)
      return cacheKey
    } catch {
      Logger.logError("[Sessions:Settings] Error: \(error)")
    }
    return nil
  }
}
