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

/// Mock options to configure default Firebase app.
private enum MockOptions {
  static let appID = "1:123:ios:123abc"
  static let gcmSenderID = "mock-sender-id"
  static let projectID = "mock-project-id"
  static let apiKey = "ABcdEf-APIKeyWithValidFormat_0123456789"
}

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

final class ModelDownloaderUnitTests: XCTestCase {
  override class func setUp() {
    let options = FirebaseOptions(
      googleAppID: MockOptions.appID,
      gcmSenderID: MockOptions.gcmSenderID
    )
    options.apiKey = MockOptions.apiKey
    options.projectID = MockOptions.projectID
    FirebaseApp.configure(options: options)
  }

  /// Unit test for reading and writing to user defaults.
  func testUserDefaults() {
    guard let testApp = FirebaseApp.app() else {
      XCTFail("Default app was not configured.")
      return
    }
    let functionName = #function
    let testModelName = "\(functionName)-test-model"
    let modelInfo = ModelInfo(
      app: testApp,
      name: testModelName,
      defaults: .getTestInstance()
    )
    XCTAssertEqual(modelInfo.downloadURL, "")
    modelInfo.downloadURL = "testurl.com"
    XCTAssertEqual(modelInfo.downloadURL, "testurl.com")
    XCTAssertEqual(modelInfo.modelHash, "")
    XCTAssertEqual(modelInfo.size, 0)
    XCTAssertEqual(modelInfo.path, nil)
  }

  /// Test to download model info.
  // TODO: Add unit test with mocks.
  func testDownloadModelInfo() {}

  /// Unit test to save model info to user defaults.
  func testSaveModelInfo() {
    guard let testApp = FirebaseApp.app() else {
      XCTFail("Default app was not configured.")
      return
    }
    let functionName = #function
    let testModelName = "\(functionName)-test-model"
    let modelInfoRetriever = ModelInfoRetriever(
      app: testApp,
      modelName: testModelName
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
