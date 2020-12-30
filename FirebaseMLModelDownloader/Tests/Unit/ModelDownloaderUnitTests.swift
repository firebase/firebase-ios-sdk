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
@testable import FirebaseInstallations
@testable import FirebaseMLModelDownloader

/// Mock options to configure default Firebase app.
private enum MockOptions {
  static let appID = "1:123:ios:123abc"
  static let gcmSenderID = "mock-sender-id"
  static let projectID = "mock-project-id"
  static let apiKey = "ABcdEf-APIKeyWithValidFormat_0123456789"
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

  /// Test to download model info.
  // TODO: Add unit test with mocks.
  func testDownloadModelInfo() {}

  /// Test to download model file.
  // TODO: Add unit test with mocks.
  func testStartModelDownload() {}

  func testGetModel() {
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct
    // results.
    guard let testApp = FirebaseApp.app() else {
      XCTFail("Default app was not configured.")
      return
    }

    let modelDownloader = ModelDownloader.modelDownloader()
    let modelDownloaderWithApp = ModelDownloader.modelDownloader(app: testApp)

    /// These should point to the same instance.
    XCTAssert(modelDownloader === modelDownloaderWithApp)

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
    modelDownloaderWithApp.listDownloadedModels { result in
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
