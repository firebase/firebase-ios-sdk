// Copyright 2021 Google LLC
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

// Skip keychain tests on Catalyst and macOS. Tests are skipped because they
// involve interactions with the keychain that require a provisioning profile.
// This is because MLModelDownloader depends on Installations.
// See go/firebase-macos-keychain-popups for more details.
#if !targetEnvironment(macCatalyst) && !os(macOS)

  @testable import FirebaseCore
  @testable import FirebaseInstallations
  @testable import FirebaseMLModelDownloader
  import XCTest
  #if SWIFT_PACKAGE
    @_implementationOnly import GoogleUtilities_UserDefaults
  #else
    @_implementationOnly import GoogleUtilities
  #endif // SWIFT_PACKAGE

  extension GULUserDefaults {
    /// Returns an instance of user defaults.
    static func createTestInstance(testName: String) -> GULUserDefaults {
      let suiteName = "com.google.firebase.ml.test.\(testName)"
      // Clear the suite (`UserDefaults` and `GULUserDefaults` map to the same
      // storage space and `GULUserDefaults` doesn't offer API to do this.)
      UserDefaults(suiteName: suiteName)!.removePersistentDomain(forName: suiteName)
      return GULUserDefaults(suiteName: suiteName)
    }

    /// Returns the existing user defaults instance.
    static func getTestInstance(testName: String) -> GULUserDefaults {
      let suiteName = "com.google.firebase.ml.test.\(testName)"
      return GULUserDefaults(suiteName: suiteName)
    }
  }

  final class ModelDownloaderIntegrationTests: XCTestCase {
    override class func setUp() {
      super.setUp()
      // TODO: Use FirebaseApp internal for test app.
      let bundle = Bundle(for: self)
      if let plistPath = bundle.path(forResource: "GoogleService-Info", ofType: "plist"),
         let options = FirebaseOptions(contentsOfFile: plistPath) {
        FirebaseApp.configure(options: options)
      } else {
        XCTFail("Could not locate GoogleService-Info.plist.")
      }
      FirebaseConfiguration.shared.setLoggerLevel(.debug)
    }

    override func setUp() {
      do {
        try ModelFileManager.emptyModelsDirectory()
      } catch {
        XCTFail("Could not empty models directory.")
      }
    }

    /// Test to download model info - makes an actual network call.
    func testDownloadModelInfo() {
      guard let testApp = FirebaseApp.app() else {
        XCTFail("Default app was not configured.")
        return
      }
      testApp.isDataCollectionDefaultEnabled = false

      let testName = String(#function.dropLast(2))
      let testModelName = "pose-detection"

      let modelInfoRetriever = ModelInfoRetriever(
        modelName: testModelName,
        projectID: testApp.options.projectID!,
        apiKey: testApp.options.apiKey!,
        appName: testApp.name, installations: Installations.installations(app: testApp)
      )

      let modelInfoDownloadExpectation =
        expectation(description: "Wait for model info to download.")
      modelInfoRetriever.downloadModelInfo(completion: { result in
        switch result {
        case let .success(modelInfoResult):
          switch modelInfoResult {
          case let .modelInfo(modelInfo):
            XCTAssertNotNil(modelInfo.urlExpiryTime)
            XCTAssertGreaterThan(modelInfo.downloadURL.absoluteString.count, 0)
            XCTAssertGreaterThan(modelInfo.modelHash.count, 0)
            XCTAssertGreaterThan(modelInfo.size, 0)
            let localModelInfo = LocalModelInfo(from: modelInfo)
            localModelInfo.writeToDefaults(
              .createTestInstance(testName: testName),
              appName: testApp.name
            )
          case .notModified:
            XCTFail("Failed to retrieve model info.")
          }
        case let .failure(error):
          XCTAssertNotNil(error)
          XCTFail("Failed to retrieve model info - \(error)")
        }
        modelInfoDownloadExpectation.fulfill()
      })

      wait(for: [modelInfoDownloadExpectation], timeout: 5)

      if let localInfo = LocalModelInfo(
        fromDefaults: .getTestInstance(testName: testName),
        name: testModelName,
        appName: testApp.name
      ) {
        XCTAssertNotNil(localInfo)
        testRetrieveModelInfo(localInfo: localInfo)
      } else {
        XCTFail("Could not save model info locally.")
      }
    }

    func testRetrieveModelInfo(localInfo: LocalModelInfo) {
      guard let testApp = FirebaseApp.app() else {
        XCTFail("Default app was not configured.")
        return
      }
      let testModelName = "pose-detection"

      let modelInfoRetriever = ModelInfoRetriever(
        modelName: testModelName,
        projectID: testApp.options.projectID!,
        apiKey: testApp.options.apiKey!,
        appName: testApp.name, installations: Installations.installations(app: testApp),
        localModelInfo: localInfo
      )

      let modelInfoRetrieveExpectation =
        expectation(description: "Wait for model info to be retrieved.")
      modelInfoRetriever.downloadModelInfo(completion: { result in
        switch result {
        case let .success(modelInfoResult):
          switch modelInfoResult {
          case .modelInfo:
            XCTFail("Local model info is already the latest and should not be set again.")
          case .notModified: break
          }
        case let .failure(error):
          XCTAssertNotNil(error)
          XCTFail("Failed to retrieve model info - \(error)")
        }
        modelInfoRetrieveExpectation.fulfill()
      })

      wait(for: [modelInfoRetrieveExpectation], timeout: 5)
    }

    /// Disabled since this test has been flaky in CI.
    /// From https://github.com/firebase/firebase-ios-sdk/actions/runs/9944896811/job/27471928997
    /// ModelDownloaderIntegrationTests.swift:190: XCTAssertGreaterThanOrEqual failed: ("-3106.0")
    /// is less than ("0.0")
    /// ModelDownloaderIntegrationTests.swift:190: XCTAssertGreaterThanOrEqual failed: ("-4902.0")
    /// is less than ("0.0")
    /// ModelDownloaderIntegrationTests.swift:204: error:
    ///  failed - Error: internalError(description: "Model download failed with HTTP error code:
    /// 500")
    ///
    /// Test to download model file - makes an actual network call.
    func SKIPtestModelDownload() throws {
      guard let testApp = FirebaseApp.app() else {
        XCTFail("Default app was not configured.")
        return
      }
      testApp.isDataCollectionDefaultEnabled = false

      let testName = String(#function.dropLast(2))
      let testModelName = "\(testName)-test-model"
      let urlString =
        "https://tfhub.dev/tensorflow/lite-model/ssd_mobilenet_v1/1/metadata/1?lite-format=tflite"
      let url = URL(string: urlString)!

      let remoteModelInfo = RemoteModelInfo(
        name: testModelName,
        downloadURL: url,
        modelHash: "mock-valid-hash",
        size: 10,
        urlExpiryTime: Date()
      )

      let conditions = ModelDownloadConditions()
      let downloadExpectation = expectation(description: "Wait for model to download.")
      let downloader = ModelFileDownloader(conditions: conditions)
      let taskProgressHandler: ModelDownloadTask.ProgressHandler = { progress in
        XCTAssertLessThanOrEqual(progress, 1)
        XCTAssertGreaterThanOrEqual(progress, 0)
      }
      let taskCompletion: ModelDownloadTask.Completion = { result in
        switch result {
        case let .success(model):
          let modelURL = URL(fileURLWithPath: model.path)
          XCTAssertTrue(ModelFileManager.isFileReachable(at: modelURL))
          // Remove downloaded model file.
          do {
            try ModelFileManager.removeFile(at: modelURL)
          } catch {
            XCTFail("Model removal failed - \(error)")
          }
        case let .failure(error):
          XCTFail("Error: \(error)")
        }
        downloadExpectation.fulfill()
      }
      let modelDownloadManager = ModelDownloadTask(
        remoteModelInfo: remoteModelInfo,
        appName: testApp.name,
        defaults: .createTestInstance(testName: testName),
        downloader: downloader,
        progressHandler: taskProgressHandler,
        completion: taskCompletion
      )

      modelDownloadManager.resume()
      wait(for: [downloadExpectation], timeout: 5)
      XCTAssertEqual(modelDownloadManager.downloadStatus, .complete)
    }

    func testGetModel() {
      guard let testApp = FirebaseApp.app() else {
        XCTFail("Default app was not configured.")
        return
      }
      testApp.isDataCollectionDefaultEnabled = false

      let testName = String(#function.dropLast(2))
      let testModelName = "image-classification"

      let conditions = ModelDownloadConditions()
      let modelDownloader = ModelDownloader.modelDownloaderWithDefaults(
        .createTestInstance(testName: testName),
        app: testApp
      )

      /// Test download type - latest model.
      var downloadType: ModelDownloadType = .latestModel
      let latestModelExpectation = expectation(description: "Get latest model.")

      modelDownloader.getModel(
        name: testModelName,
        downloadType: downloadType,
        conditions: conditions,
        progressHandler: { progress in
          XCTAssertTrue(Thread.isMainThread, "Completion must be called on the main thread.")

          XCTAssertLessThanOrEqual(progress, 1)
          XCTAssertGreaterThanOrEqual(progress, 0)
        }
      ) { result in
        XCTAssertTrue(Thread.isMainThread, "Completion must be called on the main thread.")

        switch result {
        case let .success(model):
          XCTAssertNotNil(model.path)
          let modelURL = URL(fileURLWithPath: model.path)
          XCTAssertTrue(ModelFileManager.isFileReachable(at: modelURL))
        case let .failure(error):
          XCTFail("Failed to download model - \(error)")
        }
        latestModelExpectation.fulfill()
      }

      wait(for: [latestModelExpectation], timeout: 5)

      /// Test download type - local model update in background.
      downloadType = .localModelUpdateInBackground
      let backgroundModelExpectation =
        expectation(description: "Get local model and update in background.")

      modelDownloader.getModel(
        name: testModelName,
        downloadType: downloadType,
        conditions: conditions,
        progressHandler: { progress in
          XCTFail("Model is already available on device.")
        }
      ) { result in
        switch result {
        case let .success(model):
          XCTAssertNotNil(model.path)
          let modelURL = URL(fileURLWithPath: model.path)
          XCTAssertTrue(ModelFileManager.isFileReachable(at: modelURL))
        case let .failure(error):
          XCTFail("Failed to download model - \(error)")
        }
        backgroundModelExpectation.fulfill()
      }
      wait(for: [backgroundModelExpectation], timeout: 5)

      /// Test download type - local model.
      downloadType = .localModel
      let localModelExpectation = expectation(description: "Get local model.")

      modelDownloader.getModel(
        name: testModelName,
        downloadType: downloadType,
        conditions: conditions,
        progressHandler: { progress in
          XCTFail("Model is already available on device.")
        }
      ) { result in
        switch result {
        case let .success(model):
          XCTAssertNotNil(model.path)
          let modelURL = URL(fileURLWithPath: model.path)
          XCTAssertTrue(ModelFileManager.isFileReachable(at: modelURL))
          // Remove downloaded model file.
          do {
            try ModelFileManager.removeFile(at: modelURL)
          } catch {
            XCTFail("Model removal failed - \(error)")
          }
        case let .failure(error):
          XCTFail("Failed to download model - \(error)")
        }
        localModelExpectation.fulfill()
      }
      wait(for: [localModelExpectation], timeout: 5)
    }

    func testGetModelWhenNameIsEmpty() {
      guard let testApp = FirebaseApp.app() else {
        XCTFail("Default app was not configured.")
        return
      }
      testApp.isDataCollectionDefaultEnabled = false

      let testName = String(#function.dropLast(2))
      let emptyModelName = ""

      let conditions = ModelDownloadConditions()
      let modelDownloader = ModelDownloader.modelDownloaderWithDefaults(
        .createTestInstance(testName: testName),
        app: testApp
      )

      let completionExpectation = expectation(description: "getModel")
      let progressExpectation = expectation(description: "progressHandler")
      progressExpectation.isInverted = true

      modelDownloader.getModel(
        name: emptyModelName,
        downloadType: .latestModel,
        conditions: conditions,
        progressHandler: { progress in
          progressExpectation.fulfill()
        }
      ) { result in
        XCTAssertTrue(Thread.isMainThread, "Completion must be called on the main thread.")

        switch result {
        case .failure(.emptyModelName):
          // The expected error.
          break

        default:
          XCTFail("Unexpected result: \(result)")
        }
        completionExpectation.fulfill()
      }

      wait(for: [completionExpectation, progressExpectation], timeout: 5)
    }

    /// Delete previously downloaded model.
    func testDeleteModel() {
      guard let testApp = FirebaseApp.app() else {
        XCTFail("Default app was not configured.")
        return
      }
      testApp.isDataCollectionDefaultEnabled = false

      let testName = String(#function.dropLast(2))
      let testModelName = "pose-detection"

      let conditions = ModelDownloadConditions()
      let modelDownloader = ModelDownloader.modelDownloaderWithDefaults(
        .createTestInstance(testName: testName),
        app: testApp
      )

      let downloadType: ModelDownloadType = .latestModel
      let latestModelExpectation = expectation(description: "Get latest model for deletion.")

      modelDownloader.getModel(
        name: testModelName,
        downloadType: downloadType,
        conditions: conditions,
        progressHandler: { progress in
          XCTAssertTrue(Thread.isMainThread, "Completion must be called on the main thread.")
          XCTAssertLessThanOrEqual(progress, 1)
          XCTAssertGreaterThanOrEqual(progress, 0)
        }
      ) { result in
        XCTAssertTrue(Thread.isMainThread, "Completion must be called on the main thread.")

        switch result {
        case let .success(model):
          XCTAssertNotNil(model.path)
          let filePath = URL(fileURLWithPath: model.path)
          XCTAssertTrue(ModelFileManager.isFileReachable(at: filePath))
        case let .failure(error):
          XCTFail("Failed to download model - \(error)")
        }
        latestModelExpectation.fulfill()
      }

      wait(for: [latestModelExpectation], timeout: 5)

      let deleteExpectation = expectation(description: "Wait for model deletion.")
      modelDownloader.deleteDownloadedModel(name: testModelName) { result in
        deleteExpectation.fulfill()
        XCTAssertTrue(Thread.isMainThread, "Completion must be called on the main thread.")

        switch result {
        case .success: break
        case let .failure(error):
          XCTFail("Failed to delete model - \(error)")
        }
      }

      wait(for: [deleteExpectation], timeout: 5)
    }

    /// Test listing models in model directory.
    func testListModels() {
      guard let testApp = FirebaseApp.app() else {
        XCTFail("Default app was not configured.")
        return
      }
      testApp.isDataCollectionDefaultEnabled = false

      let testName = String(#function.dropLast(2))
      let testModelName = "pose-detection"

      let conditions = ModelDownloadConditions()
      let modelDownloader = ModelDownloader.modelDownloaderWithDefaults(
        .createTestInstance(testName: testName),
        app: testApp
      )

      let downloadType: ModelDownloadType = .latestModel
      let latestModelExpectation = expectation(description: "Get latest model.")

      modelDownloader.getModel(
        name: testModelName,
        downloadType: downloadType,
        conditions: conditions,
        progressHandler: { progress in
          XCTAssertLessThanOrEqual(progress, 1)
          XCTAssertGreaterThanOrEqual(progress, 0)
        }
      ) { result in
        switch result {
        case let .success(model):
          XCTAssertNotNil(model.path)
          let filePath = URL(fileURLWithPath: model.path)
          XCTAssertTrue(ModelFileManager.isFileReachable(at: filePath))
        case let .failure(error):
          XCTFail("Failed to download model - \(error)")
        }
        latestModelExpectation.fulfill()
      }

      wait(for: [latestModelExpectation], timeout: 5)

      let listExpectation = expectation(description: "Wait for list models.")
      modelDownloader.listDownloadedModels { result in
        listExpectation.fulfill()
        switch result {
        case let .success(models):
          XCTAssertGreaterThan(models.count, 0)
        case let .failure(error):
          XCTFail("Failed to list models - \(error)")
        }
      }

      wait(for: [listExpectation], timeout: 5)
    }

    /// Test logging telemetry event.
    func testLogTelemetryEvent() {
      guard let testApp = FirebaseApp.app() else {
        XCTFail("Default app was not configured.")
        return
      }
      // Flip this to `true` to test logging.
      testApp.isDataCollectionDefaultEnabled = false

      let testModelName = "digit-classification"
      let testName = String(#function.dropLast(2))

      let conditions = ModelDownloadConditions()
      let modelDownloader = ModelDownloader.modelDownloaderWithDefaults(
        .createTestInstance(testName: testName),
        app: testApp
      )

      let latestModelExpectation = expectation(description: "Test get model telemetry.")

      modelDownloader.getModel(
        name: testModelName,
        downloadType: .latestModel,
        conditions: conditions
      ) { result in
        switch result {
        case .success: break
        case let .failure(error):
          XCTFail("Failed to download model - \(error)")
        }
        latestModelExpectation.fulfill()
      }
      wait(for: [latestModelExpectation], timeout: 5)

      let deleteModelExpectation = expectation(description: "Test delete model telemetry.")
      modelDownloader.deleteDownloadedModel(name: testModelName) { result in
        switch result {
        case .success(()): break
        case let .failure(error):
          XCTFail("Failed to delete model - \(error)")
        }
        deleteModelExpectation.fulfill()
      }

      wait(for: [deleteModelExpectation], timeout: 5)

      let notFoundModelName = "fakeModelName"
      let notFoundModelExpectation =
        expectation(description: "Test get model telemetry with unknown model.")

      modelDownloader.getModel(
        name: notFoundModelName,
        downloadType: .latestModel,
        conditions: conditions
      ) { result in
        switch result {
        case .success: XCTFail("Unexpected model success.")
        case let .failure(error):
          XCTAssertEqual(error, .notFound)
        }
        notFoundModelExpectation.fulfill()
      }
      wait(for: [notFoundModelExpectation], timeout: 5)
    }

    func testGetModelWithConditions() {
      guard let testApp = FirebaseApp.app() else {
        XCTFail("Default app was not configured.")
        return
      }
      testApp.isDataCollectionDefaultEnabled = false

      let testModelName = "pose-detection"
      let testName = String(#function.dropLast(2))

      let conditions = ModelDownloadConditions(allowsCellularAccess: false)

      let modelDownloader = ModelDownloader.modelDownloaderWithDefaults(
        .createTestInstance(testName: testName),
        app: testApp
      )

      let latestModelExpectation = expectation(description: "Get latest model with conditions.")

      modelDownloader.getModel(
        name: testModelName,
        downloadType: .latestModel,
        conditions: conditions,
        progressHandler: { progress in
          XCTAssertTrue(Thread.isMainThread, "Completion must be called on the main thread.")
          XCTAssertLessThanOrEqual(progress, 1)
          XCTAssertGreaterThanOrEqual(progress, 0)
        }
      ) { result in
        XCTAssertTrue(Thread.isMainThread, "Completion must be called on the main thread.")

        switch result {
        case let .success(model):
          XCTAssertNotNil(model.path)
          let filePath = URL(fileURLWithPath: model.path)
          XCTAssertTrue(ModelFileManager.isFileReachable(at: filePath))
        case let .failure(error):
          XCTFail("Failed to download model - \(error)")
        }
        latestModelExpectation.fulfill()
      }
      wait(for: [latestModelExpectation], timeout: 5)
    }
  }

#endif // !targetEnvironment(macCatalyst) && !os(macOS)
