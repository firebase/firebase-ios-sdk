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

enum Constants {
  enum App {
    static let defaultName = "__FIRAPP_DEFAULT"
    static let googleAppIDKey = "FIRGoogleAppIDKey"
    static let nameKey = "FIRAppNameKey"
    static let isDefaultAppKey = "FIRAppIsDefaultAppKey"
  }

  enum Options {
    static let apiKey = "correct_api_key"
    static let bundleID = "com.google.FirebaseSDKTests"
    static let clientID = "correct_client_id"
    static let trackingID = "correct_tracking_id"
    static let gcmSenderID = "correct_gcm_sender_id"
    static let projectID = "correct_project_id"
    static let androidClientID = "correct_android_client_id"
    static let googleAppID = "correct_app_id"
    static let databaseURL = "https://abc-xyz-123.firebaseio.com"
    static let deepLinkURLScheme = "comgoogledeeplinkurl"
    static let storageBucket = "project-id-123.storage.firebase.com"
    static let appGroupID: String? = nil
  }
}

extension UserDefaults {
  /// For testing: returns a new cleared instance of user defaults.
  static func getTestInstance() -> UserDefaults {
    let suiteName = "com.google.firebase.ml.test"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
  }
}

final class ModelDownloaderTests: XCTestCase {
  override class func setUp() {
    super.setUp()
    let options = FirebaseOptions(googleAppID: Constants.Options.googleAppID,
                                  gcmSenderID: Constants.Options.gcmSenderID)
    options.apiKey = Constants.Options.apiKey
    options.projectID = Constants.Options.projectID
    options.clientID = Constants.Options.clientID
    // TODO: Replace with custom options
    FirebaseApp.configure()
  }

  /// Unit test for reading and writing to user defaults.
  func testUserDefaults() {
    let testApp = FirebaseApp.app()!
    let functionName = #function
    let testModelName = "\(functionName)-test-model"
    let modelInfoRetriever = ModelInfoRetriever(
      app: testApp,
      projectID: Constants.Options.projectID,
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
    XCTAssertEqual(modelInfoRetriever.modelInfo?.hash, "")
    XCTAssertEqual(modelInfoRetriever.modelInfo?.size, 0)
    XCTAssertEqual(modelInfoRetriever.modelInfo?.path, nil)
  }

  func testDownloadModelInfo() {
    let testApp = FirebaseApp.app()!
    let functionName = #function
    let testModelName = "\(functionName)-test-model"
    let modelInfoRetriever = ModelInfoRetriever(
      app: testApp,
      projectID: Constants.Options.projectID,
      modelName: testModelName
    )
    let expectation = self.expectation(description: "Wait for model info to download.")
    modelInfoRetriever.downloadModelInfo(completion: { error in
      guard let downloadError = error else { return }
      XCTAssertEqual(downloadError, .notFound)
      print("ERROR: Model not found on server.")
      expectation.fulfill()
    })
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
