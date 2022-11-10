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

import XCTest
@testable import FirebaseSessions

class SettingsTests: XCTestCase {
  // 2021-11-01 @ 00:00:00 (EST)
  let date = Date(timeIntervalSince1970: 1_635_739_200)
  let settingsJSONString = "{\"cache_duration\":0,\"sessions_enabled\":false,\"sampling_rate\":0.5,\"session_timeout\":10}"
//  let settingsDictionary: [String: Any] = ["cache_duration": 0, "sessions_enabled": false, "sampling_rate": 0.5, "session_timeout": 10]
  let fileManager: FileManager = .default
  var settingsFileManager: SettingsFileManager!
  var settings: Settings!
  var appInfo: MockApplicationInfo!

  override func setUp() {
    appInfo = MockApplicationInfo()
    settingsFileManager = SettingsFileManager(fileManager: fileManager)
    settings = Settings(fileManager: settingsFileManager, appInfo: appInfo)
  }
  
  func test_noCacheSaved_returnsDefaultSettings() {
    assert(settings.sessionsEnabled == true)
    assert(settings.samplingRate == 1)
    assert(settings.sessionTimeout == 30 * 60)
  }

  func test_activatedCache_returnsCachedSettings() {
    appInfo.mockAllInfo()
    write(string: settingsJSONString)
    write(string: "{\"createdAt\":\"\(date)\",\"googleAppID\":\"\(appInfo.appID)\",\"appVersion\":\"\(appInfo.synthesizedVersion)\"}", isCacheKey: true)
    settings.loadCache(googleAppID: appInfo.appID, currentTime: date.addingTimeInterval(5))
    assert(settings.isCacheExpired == true)
    assert(settings.sessionsEnabled == false)
    assert(settings.samplingRate == 0.5)
    assert(settings.sessionTimeout == 10)
  }

  func write(string: String, isCacheKey: Bool = false) {
    let path = isCacheKey ? settingsFileManager.settingsCacheKeyPath : settingsFileManager.settingsCacheContentPath
    print(path)
    do {
//      try JSONSerialization.data(withJSONObject: settingsDictionary).write(to: path)
      try string.write(
        to: path,
        atomically: true,
        encoding: .utf8
      )
    } catch {
      print("Error: \(error)")
    }
  }
}
