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

/// A custom model that is stored remotely on the server and downloaded to the device.
public struct CustomModel: Hashable {
  /// Name of the model.
  public let name: String

  /// Size of the custom model, provided by the server.
  public let size: Int

  /// Path where the model is stored on device.
  public let path: String

  /// Hash for the model, used for model verification.
  public let hash: String

  init(name: String, size: Int, path: String, hash: String) {
    self.name = name
    self.size = size
    self.path = path
    self.hash = hash
  }

  /// Convenience init to create model from local model info.
  init(localModelInfo: LocalModelInfo, path: String) {
    self.init(
      name: localModelInfo.name,
      size: localModelInfo.size,
      path: path,
      hash: localModelInfo.modelHash
    )
  }
}
