// Copyright 2021 Google LLC
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

/// Model info object with details about not-yet downloaded model.
struct RemoteModelInfo {
  /// Model name.
  let name: String

  /// Download URL for the model file, as returned by server.
  let downloadURL: URL

  /// Hash of the model, as returned by server.
  let modelHash: String

  /// Size of the model, as returned by server.
  let size: Int

  /// Model download URL expiry time, as returned by server.
  let urlExpiryTime: Date

  init(name: String, downloadURL: URL, modelHash: String, size: Int, urlExpiryTime: Date) {
    self.name = name
    self.downloadURL = downloadURL
    self.modelHash = modelHash
    self.size = size
    self.urlExpiryTime = urlExpiryTime
  }
}
