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
}

extension NSLocking {
  func synchronized<T>(_ closure: () throws -> T) rethrows -> T {
    lock()
    defer { unlock() }
    return try closure()
  }
}

protocol SettingsProtocol {
  func isCacheExpired(currentTime: Date) -> Bool
  var sessionsEnabled: Bool { get }
  var samplingRate: Double { get }
  var sessionTimeout: TimeInterval { get }
}

class Settings: SettingsProtocol {
  private static let cacheDurationSecondsDefault: TimeInterval = 60 * 60
  private let cache: SettingsCacheClient
  private let appInfo: ApplicationInfoProtocol

  var sessionsEnabled: Bool {
    guard let enabled = cache.cacheContent?["sessions_enabled"] as? Bool else {
      return true
    }
    return enabled
  }

  var samplingRate: Double {
    guard let rate = cache.cacheContent?["sampling_rate"] as? Double else {
      return 1
    }
    return rate
  }

  var sessionTimeout: TimeInterval {
    guard let timeout = cache.cacheContent?["session_timeout"] as? Double else {
      return 30 * 60
    }
    return timeout
  }

  private var cacheDurationSeconds: TimeInterval {
    guard let duration = cache.cacheContent?["cache_duration"] as? Double else {
      return Settings.cacheDurationSecondsDefault
    }
    return duration
  }

  init(cache: SettingsCacheClient = SettingsCache(),
       appInfo: ApplicationInfoProtocol) {
    self.cache = cache
    self.appInfo = appInfo
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
