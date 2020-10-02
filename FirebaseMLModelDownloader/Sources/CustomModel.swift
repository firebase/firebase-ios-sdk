// Copyright 2020 Google LLC
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

/// An enum of supported model formats.
public enum CustomModelFormat : Int {
  case unknown
  case tfLite
  case coreML
}

/// A custom model that is stored remotely on the server and downloaded to the device.
struct CustomModel {
  struct Metadata {
    public var modelSize: Int
    var modelPath: String
    public var modelHash: String
    public var modelFormat: CustomModelFormat
  }

  public let modelName: String
  public internal(set) var metadata: Metadata?


  init(name: String) {
    modelName = name
  }

  public func getLatestModel() -> FileHandle? {
    if let filePath = metadata?.modelPath, let modelFile = FileHandle(forReadingAtPath: filePath) {
      return modelFile
    } else {
      return nil
    }
  }

}
