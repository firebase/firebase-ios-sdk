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

public struct MLModelDownloader {

  public func codeSample() {
    let modelDownloader = ModelDownloader()

    // Download model
    modelDownloader.downloadModel(name: "your_model_name", conditions: <#T##modelConditions: ModelDownloadConditions##ModelDownloadConditions#>) { customModel, error in
      if error == nil {
        if let path = customModel.getLatestModel() {
          // Use model with your inference API
        }
      }
    }

    // Get downloaded model
    modelDownloader.getDownloadedModel(name: "your_model_name") { customModel, error in
      if error == nil {
        if let path = customModel.getLatestModel() {
          // Use model with your inference API
        }
      }
    }

    // Check model download status
    modelDownloader.isModelDownloaded(name: "your_model_name") { isDownloaded, error in
      if isDownloaded {
        // Get model using getDownloadedModel and use with your inference API
      }
    }

    // Access array of downloaded models
    modelDownloader.listDownloadedModels() { customModels, error in
      if error == nil {
        // Pick model(s) for further use
      }
    }

    // Delete downloaded model
    modelDownloader.deleteDownloadedModel(name: "your_model_name") { error in
      if error == nil {
        // Apply any other clean up
      }
    }
  }
}
