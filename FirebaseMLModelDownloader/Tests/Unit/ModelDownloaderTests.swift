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

extension UserDefaults {
  /// For testing: returns a new cleared instance of user defaults.
  static func getTestInstance() -> UserDefaults {
    let suiteName = "com.google.firebase.ml.test"
    // TODO: reconsider force unwrapping
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
  }
}

final class ModelDownloaderTests: XCTestCase {
  override class func setUp() {
    super.setUp()
    FirebaseApp.configure()
  }

  /// Unit test for reading and writing to user defaults.
  func testUserDefaults() {
    let testApp = FirebaseApp.app()!
    let functionName = #function
    let testModelName = "\(functionName)-test-model"
    let modelInfoRetriever = ModelInfoRetriever(
      app: testApp,
      modelName: testModelName
    )

    modelInfoRetriever.modelInfo = ModelInfo(
      app: testApp,
      name: testModelName,
      defaults: .getTestInstance()
    )
    XCTAssertEqual(modelInfoRetriever.modelInfo?.downloadURL, "")
    modelInfoRetriever.modelInfo?.downloadURL = "testurl.com"
    XCTAssertEqual(modelInfoRetriever.modelInfo?.downloadURL, "testurl.com")
    XCTAssertEqual(modelInfoRetriever.modelInfo?.modelHash, "")
    XCTAssertEqual(modelInfoRetriever.modelInfo?.size, 0)
    XCTAssertEqual(modelInfoRetriever.modelInfo?.path, nil)
  }

  func testDownloadModelInfo() {
    let testApp = FirebaseApp.app()!
    let testModelName = "image-classification"
    let modelInfoRetriever = ModelInfoRetriever(
      app: testApp,
      modelName: testModelName
    )
    let expectation = self.expectation(description: "Wait for model info to download.")
    modelInfoRetriever.downloadModelInfo(completion: { error in
      XCTAssertNil(error)
      XCTAssertNotNil(modelInfoRetriever.modelInfo)
      XCTAssertNotEqual(modelInfoRetriever.modelInfo!.downloadURL, "")
      XCTAssertNotEqual(modelInfoRetriever.modelInfo!.modelHash, "")
      XCTAssertGreaterThan(modelInfoRetriever.modelInfo!.size, 0)
      expectation.fulfill()
    })
    waitForExpectations(timeout: 5, handler: nil)
  }

  func testSaveModelInfo() {
    let testApp = FirebaseApp.app()!
    let functionName = #function
    let testModelName = "\(functionName)-test-model"
    let modelInfoRetriever = ModelInfoRetriever(
      app: testApp,
      modelName: testModelName
    )
    modelInfoRetriever.modelInfo = ModelInfo(
      app: testApp,
      name: testModelName,
      defaults: .getTestInstance()
    )
    let sampleResponse: String = """
    {
    "downloadUri": "https://storage.googleapis.com",
    "expireTime": "2020-11-10T04:58:49.643Z",
    "sizeBytes": "562336"
    }
    """
    let data: Data = sampleResponse.data(using: .utf8)!
    modelInfoRetriever.saveModelInfo(data: data, modelHash: "test-model-hash")
    XCTAssertEqual(modelInfoRetriever.modelInfo?.downloadURL, "https://storage.googleapis.com")
    XCTAssertEqual(modelInfoRetriever.modelInfo?.size, 562_336)
  }

  func testStartModelDownload() {
    let testApp = FirebaseApp.app()!
    let functionName = #function
    let testModelName = "\(functionName)-test-model"
    let modelInfoRetriever = ModelInfoRetriever(
      app: testApp,
      modelName: testModelName
    )
    modelInfoRetriever.modelInfo = ModelInfo(
      app: testApp,
      name: testModelName,
      defaults: .getTestInstance()
    )

    let url =
      URL(
        string: "https://tfhub.dev/tensorflow/lite-model/ssd_mobilenet_v1/1/metadata/1?lite-format=tflite"
      )!
    let modelDownloadManager = ModelDownloadManager(
      app: testApp,
      modelInfo: modelInfoRetriever.modelInfo!
    )
    let expectation = self.expectation(description: "Wait for model to download.")
    modelDownloadManager.startModelDownload(url: url, progressHandler: nil) { result in
      switch result {
      case let .success(model):
        XCTAssertEqual(modelDownloadManager.didFinishDownloading, true)
        print(model)
      case let .failure(error):
        XCTAssertNotNil(error)
      }
      expectation.fulfill()
    }
    waitForExpectations(timeout: 10, handler: nil)
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
