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

@objc(FIRCustomModelFormat) public enum CustomModelFormat : Int {
  case Unknown
  case TFLite
  case TorchScript
  case CoreML
}

@objc(FIRCustomModel) public class CustomModel : NSObject {

  public let modelName: String
  public internal(set) var modelSize: Int?
  public internal(set) var modelPath: String?
  public internal(set) var modelHash: String?
  public internal(set) var modelFormat: CustomModelFormat?

  init(withName name: String) {
    modelName = name
  }

  public func getLatestModel() -> FileHandle? {
    if let filePath = modelPath, let modelFile = FileHandle(forReadingAtPath: filePath) {
      return modelFile
    } else {
      return nil
    }
  }

}
