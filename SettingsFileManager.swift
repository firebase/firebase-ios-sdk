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

class SettingsFileManager {
  private static let directoryName: String = "com.firebase.sessions.data-v1"
  private let fileManager: FileManager
  private let directoryUrl: URL
  
  var settingsCacheContentPath: URL {
    get { return self.directoryUrl.appending(path: "settings.json") }
  }
  var settingsCacheKeyPath: URL {
    get { return self.directoryUrl.appending(path: "cache-key.json") }
  }
  
  init(fileManager: FileManager = FileManager.default) {
    self.fileManager = fileManager
    self.directoryUrl = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
    self.directoryUrl.appending(path: SettingsFileManager.directoryName)
  }
  
  func data(contentsOf url: URL) {
    return Data(contentsOf: url)
  }
}
