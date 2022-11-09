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

  private static let cacheDurationSecondsDefault: TimeInterval = 60 * 60
  private let fileManager: SettingsFileManager
  private let appInfo: ApplicationInfoProtocol
  private var settingsDictionary: [String: AnyObject]?
  private var isCacheKeyExpired: Bool
  struct CacheKey: Decodable {
    var createdAt: Date
    var googleAppID: String
    var appVersion: String
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
      // TODO: delete file
      return
    }
    settingsDictionary = parsedDictionary
    guard let cacheKeyData = fileManager.data(contentsOf: fileManager.settingsCacheKeyPath),
          let cacheKey = cacheKeyData.cacheKeyValue else {
      Logger.logError("[Sessions:Settings] Could not load settings cache key")
      // TODO: delete file
      return
    }
    guard cacheKey.googleAppID == googleAppID else {
      Logger
        .logDebug("[Sessions:Settings] Invalidating settings cache because Google App ID changed")
      // TODO: delete file
      return
    }
    if currentTime.timeIntervalSince(cacheKey.createdAt) > cacheDurationSeconds {
      Logger.logDebug("[Sessions:Settings] Settings TTL expired")
      isCacheKeyExpired = true
    }
    if appInfo.synthesizedVersion != cacheKey.appVersion {
      Logger.logDebug("[Sessions:Settings] Settings expired because app version changed")
      isCacheKeyExpired = true
    }
  }
}

private extension ApplicationInfoProtocol {
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
