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

extension UserDefaults {
  /// For testing: returns a new cleared instance of user defaults.
  @discardableResult static func getTestInstance(cleared: Bool = true) -> UserDefaults {
    let suiteName = "com.google.firebase.ml.test"
    // TODO: reconsider force unwrapping
    let defaults = UserDefaults(suiteName: suiteName)!
    if cleared {
      defaults.removePersistentDomain(forName: suiteName)
    }
    return defaults
  }
}

final class ModelDownloaderIntegrationTests: XCTestCase {
  override class func setUp() {
    super.setUp()
    let bundle = Bundle(for: self)
    if let plistPath = bundle.path(forResource: "GoogleService-Info", ofType: "plist"),
      let options = FirebaseOptions(contentsOfFile: plistPath) {
      FirebaseApp.configure(options: options)
    } else {
      XCTFail("Could not locate GoogleService-Info.plist.")
    }
  }

  /// Test to download model info - makes an actual network call.
  func testDownloadModelInfo() {
    guard let testApp = FirebaseApp.app() else {
      XCTFail("Default app was not configured.")
      return
    }
    let testModelName = "pose-detection"

    let modelInfoRetriever = ModelInfoRetriever(
      modelName: testModelName,
      options: testApp.options,
      installations: Installations.installations(app: testApp),
      appName: testApp.name
    )

    let downloadExpectation = expectation(description: "Wait for model info to download.")
    modelInfoRetriever.downloadModelInfo(completion: { result in
      switch result {
      case let .success(remoteModelInfo):
        if let modelInfo = remoteModelInfo {
          XCTAssertGreaterThan(modelInfo.downloadURL.absoluteString.count, 0)
          XCTAssertGreaterThan(modelInfo.modelHash.count, 0)
          XCTAssertGreaterThan(modelInfo.size, 0)
          let localModelInfo = LocalModelInfo(from: modelInfo, path: "mock-valid-path")
          localModelInfo.writeToDefaults(.getTestInstance(), appName: testApp.name)
        } else {
          XCTFail("Failed to retrieve model info.")
        }
      case let .failure(error):
        XCTAssertNotNil(error)
        XCTFail("Failed to retrieve model info - \(error)")
      }
      downloadExpectation.fulfill()
    })

    waitForExpectations(timeout: 5, handler: nil)
  }

  /// Test to download model file - makes an actual network call.
  func testResumeModelDownload() throws {
    let testApp = FirebaseApp.app()!
    let functionName = #function.dropLast(2)
    let testModelName = "\(functionName)-test-model"
    let urlString =
      "https://tfhub.dev/tensorflow/lite-model/ssd_mobilenet_v1/1/metadata/1?lite-format=tflite"
    let url = URL(string: urlString)!

    let remoteModelInfo = RemoteModelInfo(
      name: testModelName,
      downloadURL: url,
      modelHash: "mock-valid-hash",
      size: 10
    )

    let expectation = self.expectation(description: "Wait for model to download.")
    let modelDownloadManager = ModelDownloadTask(
      remoteModelInfo: remoteModelInfo,
      appName: testApp.name,
      defaults: .getTestInstance(),
      progressHandler: { progress in
        XCTAssertNotNil(progress)
      }
    ) { result in
      switch result {
      case let .success(model):
        guard let modelPath = URL(string: model.path) else {
          XCTFail("Invalid or empty model path.")
          return
        }
        XCTAssertTrue(ModelFileManager.isFileReachable(at: modelPath))
      case let .failure(error):
        XCTFail("Error: \(error)")
      }
      expectation.fulfill()
    }

    modelDownloadManager.resumeModelDownload()
    waitForExpectations(timeout: 5, handler: nil)
    XCTAssertEqual(modelDownloadManager.downloadStatus, .completed)
  }
}
