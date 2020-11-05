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

import XCTest
@testable import FirebaseCore
@testable import FirebaseMLModelDownloader

final class ModelDownloaderTests: XCTestCase {
  /// Unit test for reading and writing to user defaults.
  func testUserDefaults() {
    FirebaseApp.configure()
    let testApp = FirebaseApp.app()!
    let testModelName = "user-defaults-test-model"
    let modelInfoRetriever = ModelInfoRetriever(
      app: testApp,
      modelName: testModelName,
      defaults: .getTestInstance()
    )
    modelInfoRetriever.modelInfo = ModelInfo(app: testApp, name: testModelName)
    // XCTAssertEqual(modelInfoRetriever.modelInfo?.downloadURL, "")
    modelInfoRetriever.modelInfo?.downloadURL = "testurl.com"
    XCTAssertEqual(modelInfoRetriever.modelInfo?.downloadURL, "testurl.com")
    XCTAssertEqual(modelInfoRetriever.modelInfo?.hash, "")
    XCTAssertEqual(modelInfoRetriever.modelInfo?.size, 0)
    XCTAssertEqual(modelInfoRetriever.modelInfo?.path, nil)
  }

  func testExample() {
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct
    // results.
    let modelDownloader = ModelDownloader()
    let conditions = ModelDownloadConditions()

    // Download model w/ progress handler
    modelDownloader.getModel(
      name: "your_model_name",
      downloadType: .latestModel,
      conditions: conditions,
      progressHandler: { progress in
        // Handle progress
      }
    ) { result in
      switch result {
      case .success:
        // Use model with your inference API
        // let interpreter = Interpreter(modelPath: customModel.modelPath)
        break
      case .failure:
        // Handle download error
        break
      }
    }

    // Access array of downloaded models
    modelDownloader.listDownloadedModels { result in
      switch result {
      case .success:
        // Pick model(s) for further use
        break
      case .failure:
        // Handle failure
        break
      }
    }

    // Delete downloaded model
    modelDownloader.deleteDownloadedModel(name: "your_model_name") { result in
      switch result {
      case .success():
        // Apply any other clean up
        break
      case .failure:
        // Handle failure
        break
      }
    }
  }
}
