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

// TODO: break this up into separate unit and integration tests
final class ModelDownloaderTests: XCTestCase {
  override class func setUp() {
    super.setUp()
    guard let plistPath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"), let options = FirebaseOptions(contentsOfFile: plistPath) else {
      XCTFail("GoogleService-Info.plist not found.")
      return
    }
    FirebaseApp.configure(options: options)
  }

  /// Unit test for reading and writing to user defaults.
  func testUserDefaults() {
    let testApp = FirebaseApp.app()!
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

  /// Test to retrieve FIS token - makes an actual network call.
  // TODO: Move this into a separate integration test and add unit test with mocks.
  func testGetAuthToken() {
    let testApp = FirebaseApp.app()!
    let testModelName = "image-classification"
    let modelInfoRetriever = ModelInfoRetriever(
      app: testApp,
      modelName: testModelName,
      defaults: .getTestInstance()
    )
    let expectation = self.expectation(description: "Wait for FIS auth token.")
    modelInfoRetriever.getAuthToken(completion: { result in
      switch result {
      case let .success(token):
        XCTAssertNotNil(token)
      case let .failure(error):
        XCTFail(error.localizedDescription)
      }
      expectation.fulfill()

    })
    waitForExpectations(timeout: 5, handler: nil)
  }

  /// Test to download model info - makes an actual network call.
  // TODO: Move this into a separate integration test and add unit test with mocks.
  func testDownloadModelInfo() {
    let testApp = FirebaseApp.app()!
    let testModelName = "pose-detection"
    let modelInfoRetriever = ModelInfoRetriever(
      app: testApp,
      modelName: testModelName,
      defaults: .getTestInstance()
    )
    let downloadExpectation = expectation(description: "Wait for model info to download.")
    modelInfoRetriever.downloadModelInfo(completion: { error in
      XCTAssertNil(error)
      guard let modelInfo = modelInfoRetriever.modelInfo else {
        XCTFail("Empty model info.")
        return
      }
      XCTAssertNotEqual(modelInfo.downloadURL, "")
      XCTAssertNotEqual(modelInfo.modelHash, "")
      XCTAssertGreaterThan(modelInfo.size, 0)
      downloadExpectation.fulfill()
    })

    waitForExpectations(timeout: 5, handler: nil)

    let retrieveExpectation = expectation(description: "Wait for model info to be retrieved.")
    modelInfoRetriever.downloadModelInfo(completion: { error in
      XCTAssertNil(error)
      guard let modelInfo = modelInfoRetriever.modelInfo else {
        XCTFail("Empty model info.")
        return
      }
      XCTAssertNotEqual(modelInfo.downloadURL, "")
      XCTAssertNotEqual(modelInfo.modelHash, "")
      XCTAssertGreaterThan(modelInfo.size, 0)
      retrieveExpectation.fulfill()
    })

    waitForExpectations(timeout: 500, handler: nil)
  }

  /// Unit test to save model info to user defaults.
  func testSaveModelInfo() {
    let testApp = FirebaseApp.app()!
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
