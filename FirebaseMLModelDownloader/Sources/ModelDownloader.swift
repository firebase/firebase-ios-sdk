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

@objc(FIRModelDownloader) public class ModelDownloader : NSObject {

  public func downloadModel(name modelName: String, conditions modelConditions: ModelDownloadConditions, completion: @escaping (CustomModel, Error?) -> Void) {
    let customModel = CustomModel(withName: modelName)
    // TODO: Model download
    completion(customModel, NSError())
  }

  public func isModelDownloaded(name modelName: String, completion: @escaping (Bool, Error?) -> Void) {
    let modelStatus = Bool()
    // TODO: Model status check
    completion(modelStatus, NSError())
  }

  public func getDownloadedModel(name modelName: String, completion: @escaping (CustomModel, Error?) -> Void) {
    let customModel = CustomModel(withName: modelName)
    // TODO: Get previously downloaded model
    completion(customModel, NSError())
  }

  public func listDownloadedModels(completion: @escaping ([CustomModel], Error?) -> Void) {
    let customModels = [CustomModel]()
    // TODO: List downloaded models
    completion(customModels, NSError())
  }

  public func deleteDownloadedModel(name modelName: String, completion: @escaping (Error?) -> Void) {
    // TODO: Delete previously downloaded model
    completion(NSError())
  }
}
