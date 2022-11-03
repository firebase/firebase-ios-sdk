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

class Settings {
  private let settingsDictionary: [:]
  private let fileManager: SettingsFileManager
  private var isCacheKeyExpired: Bool
  var isCacheExpired: Bool {
    get {
      guard let dictionary = settingsDictionary else {
        return true
      }
      return isCacheKeyExpired
    }
  }
  private var cacheDurationSeconds: UInt32 {
    get {
      if let duration = settingsDictionary["cache_duration"] {
        return duration
      }
      return 60 * 60
    }
  }
  struct CacheKey: Decodable {
    var createdAt: Date
    var googleAppID: String
    var buildInstanceID: String
    var appVersion: String
  }
  
  init(fileManager: SettingsFileManager = SettingsFileManager()) {
    self.fileManager = fileManager
    self.isCacheKeyExpired = false
  }
  
  func loadCache(googleAppID: String, currentTime: Date) {
    guard let cacheData = fileManager.data(contentsOf: fileManager.settingsCacheContentPath) else {
      Logger.logDebug("[Sessions:Settings] No settings were cached")
      return
    }
    guard settingsDictionary = parseDictionary(data: cacheData) else {
      // TODO: delete file
      return
    }
    guard let cacheKeyData = fileManager.data(contentsOf: fileManager.settingsCacheKeyPath), let cacheKey = parseCacheKey(data: cacheKeyData) else {
      Logger.logError("[Sessions:Settings] Could not load settings cache key")
      // TODO: delete file
      return
    }
    guard cacheKey.googleAppID == googleAppID else {
      Logger.logDebug("[Sessions:Settings] Invalidating settings cache because Google App ID changed")
      // TODO: delete file
      return
    }
    guard currentTime.timeIntervalSince(cacheKey.createdAt) > cacheDurationSeconds else {
      Logger.logDebug("[Sessions:Settings] Settings TTL expired")
      self.isCacheKeyExpired = true
    }
  }
  
  func parseDictionary(data: Data) -> [String: AnyObject]? {
    do {
      let json = try JSONSerialization.jsonObject(with: data)
      if let dictionary = json as? [String: AnyObject] {
        return dictionary
      } else {
        Logger.logError("[Sessions:Settings] Could not cast JSON object as a Dictionary<String, Any>")
      }
    } catch {
      Logger.logError("[Sessions:Settings] Error: \(error)")
    }
    return nil
  }
  
  func parseCacheKey(data: Data) -> CacheKey? {
    do {
      let cacheKey = try JSONDecoder().decode(CacheKey.self, from: data)
      return cacheKey
    } catch {
      Logger.logError("[Sessions:Settings] Error: \(error)")
    }
    return nil
  }
}
