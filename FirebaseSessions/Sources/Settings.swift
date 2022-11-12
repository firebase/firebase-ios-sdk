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
          .logError("[Settings] Could not cast JSON object as a Dictionary<String, Any>")
      }
    } catch {
      Logger.logError("[Settings] Error: \(error)")
    }
    return nil
  }

  var cacheKeyValue: Settings.CacheKey? {
    do {
      let cacheKey = try JSONDecoder().decode(Settings.CacheKey.self, from: self)
      return cacheKey
    } catch {
      Logger.logError("[Settings] Error: \(error)")
    }
    return nil
  }
}

extension NSLocking {
  func synchronized<T>(_ closure: () throws -> T) rethrows -> T {
    lock()
    defer { unlock() }
    return try closure()
  }
}

protocol SettingsProtocol {
  func loadCache(googleAppID: String, currentTime: Date)
  var sessionsEnabled: Bool { get }
  var samplingRate: Double { get }
  var sessionTimeout: TimeInterval { get }
}

class Settings: SettingsProtocol {
  private static let cacheDurationSecondsDefault: TimeInterval = 60 * 60
  private let fileManager: SettingsFileManagerProtocol
  private let appInfo: ApplicationInfoProtocol
  // Underscored variables may be accessed in different threads,
  private let lock = NSLock()
  private var _settingsDictionary: [String: AnyObject]?
  private var _isCacheKeyExpired: Bool
  struct CacheKey: Codable {
    var createdAt: Date
    var googleAppID: String
    var appVersion: String
  }

  var settingsDictionary: [String: AnyObject]? {
    lock.synchronized {
      _settingsDictionary
    }
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
    return lock.synchronized {
      return _isCacheKeyExpired
    }
  }

  private var cacheDurationSeconds: TimeInterval {
    guard let duration = settingsDictionary?["cache_duration"]?.doubleValue else {
      return Settings.cacheDurationSecondsDefault
    }
    return duration
  }

  init(fileManager: SettingsFileManagerProtocol = SettingsFileManager(),
       appInfo: ApplicationInfoProtocol) {
    self.fileManager = fileManager
    _isCacheKeyExpired = false
    self.appInfo = appInfo
  }

  func loadCache(googleAppID: String, currentTime: Date) {
    guard let cacheData = fileManager.data(contentsOf: fileManager.settingsCacheContentPath) else {
      Logger.logDebug("[Settings] No settings were cached")
      return
    }
    guard let parsedDictionary = cacheData.dictionaryValue else {
      removeCache()
      return
    }
    lock.synchronized {
      _settingsDictionary = parsedDictionary
    }
    guard let cacheKeyData = fileManager.data(contentsOf: fileManager.settingsCacheKeyPath),
          let cacheKey = cacheKeyData.cacheKeyValue else {
      Logger.logError("[Settings] Could not load settings cache key")
      removeCache()
      return
    }
    guard cacheKey.googleAppID == googleAppID else {
      Logger
        .logDebug("[Settings] Cache expired because Google App ID changed")
      removeCache()
      return
    }
    if currentTime.timeIntervalSince(cacheKey.createdAt) > cacheDurationSeconds {
      Logger.logDebug("[Settings] Cache TTL expired")
      lock.synchronized {
        _isCacheKeyExpired = true
      }
    }
    if appInfo.synthesizedVersion != cacheKey.appVersion {
      Logger.logDebug("[Settings] Cache expired because app version changed")
      lock.synchronized {
        _isCacheKeyExpired = true
      }
    }
  }

  private func removeCache() {
    fileManager.removeCacheFilesAsync()
    lock.synchronized {
      _isCacheKeyExpired = true
      _settingsDictionary = nil
    }
  }
}
