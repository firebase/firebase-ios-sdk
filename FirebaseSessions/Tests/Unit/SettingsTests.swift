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
  let settingsJSONString = "{\"cache_duration\":0}"
  let fileManager: FileManager = FileManager.default
  var settingsFileManager: SettingsFileManager!
  var settings: Settings!
  
  override func setUp() {
    settingsFileManager = SettingsFileManager(fileManager: self.fileManager)
    settings = Settings(fileManager: settingsFileManager)
  }
  
  func test_activatedCache_returnsCachedSettings() {
    write(settings: settingsJSONString)
    assert(settings.isCacheExpired == true)
  }
  
  func write(settings string: String) {
    do {
      try string.write(to: settingsFileManager.settingsCacheContentPath, atomically: true, encoding: .utf8)
    } catch {
      print("Error: \(error)")
    }
  }
}
