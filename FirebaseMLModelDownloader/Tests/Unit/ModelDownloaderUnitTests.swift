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

// TODO: Create separate files for each class tested.
final class ModelDownloaderUnitTests: XCTestCase {
  let fakeModelName = "fakeModelName"
  let fakeModelPath = "fakeModelPath"
  let fakeModelHash = "fakeModelHash"
  let fakeDownloadURL = URL(string: "www.fake-download-url.com")!
  let fakeFileURL = URL(string: "www.fake-model-file.com")!
  let fakeExpiryTime = "2021-01-20T04:20:10.220Z"
  let fakeModelSize = 20
  let fakeProjectID = "fakeProjectID"
  let fakeAPIKey = "fakeAPIKey"
  let fakeAppName = "fakeAppName"
  var fakeModelJSON: String {
    """
    {
      "downloadUri":"\(fakeDownloadURL)",
      "expireTime":"\(fakeExpiryTime)",
      "sizeBytes":"\(fakeModelSize)"
    }
    """
  }

  let successAuthTokenProvider =
    { (completion: @escaping (Result<String, DownloadError>) -> Void) in
      completion(.success("fakeFISToken"))
    }

  override class func setUp() {
    let options = FirebaseOptions(
      googleAppID: MockOptions.appID,
      gcmSenderID: MockOptions.gcmSenderID
    )
    options.apiKey = MockOptions.apiKey
    options.projectID = MockOptions.projectID
    FirebaseApp.configure(options: options)
    FirebaseConfiguration.shared.setLoggerLevel(.debug)
  }

  override func setUp() {
    try? ModelFileManager.emptyModelsDirectory()
  }

  override class func tearDown() {
    FirebaseApp.app()?.delete { _ in }
  }

  /// Test if the same downloader instance is returned for an app.
  func testModelDownloaderInit() {
    guard let testApp = FirebaseApp.app() else {
      XCTFail("Default app was not configured.")
      return
    }
    let modelDownloader1 = ModelDownloader.modelDownloader(app: testApp)
    let modelDownloader2 = ModelDownloader.modelDownloader()
    XCTAssert(modelDownloader1 === modelDownloader2)
  }

  /// Test if app deletion removes associated downloader instance.
  func testAppDeletion() {
    guard let testApp = FirebaseApp.app() else {
      XCTFail("Default app was not configured.")
      return
    }
    let modelDownloader1 = ModelDownloader.modelDownloader()
    testApp.delete { success in
      XCTAssertTrue(success)
    }
    ModelDownloaderUnitTests.setUp()
    let modelDownloader2 = ModelDownloader.modelDownloader()
    XCTAssert(modelDownloader1 !== modelDownloader2)
  }

  /// Test invalid model file deletion.
  func testDeleteInvalidModel() {
    let modelDownloader = ModelDownloader.modelDownloader()
    modelDownloader.deleteDownloadedModel(name: fakeModelName) { result in
      switch result {
      case .success: XCTFail("Unexpected successful model deletion.")
      case let .failure(error):
        XCTAssertNotNil(error)
      }
    }
  }

  func testGetModelNameFromFilePath() {
    var fakeURL = URL(fileURLWithPath: "modelDirectory/@@appName@@\(fakeModelName)")
    XCTAssertEqual(ModelFileManager.getModelNameFromFilePath(fakeURL), fakeModelName)
    fakeURL = URL(fileURLWithPath: "modelDirectory/--appName--\(fakeModelName)")
    XCTAssertNil(ModelFileManager.getModelNameFromFilePath(fakeURL))
  }

  /// Test listing models.
  // TODO: This test fails when run together with other tests, possibly due to FileManager race condition?
  func testListModels() {
    guard let testApp = FirebaseApp.app() else {
      XCTFail("Default app was not configured.")
      return
    }

    let tempModelFileURL = tempModelFile()
    let completionExpectation = expectation(description: "Completion handler")

    let localModelInfo = fakeLocalModelInfo()
    localModelInfo.writeToDefaults(.createTestInstance(testName: #function), appName: testApp.name)

    let modelDownloader = ModelDownloader.modelDownloaderWithDefaults(
      .getTestInstance(testName: #function),
      app: testApp
    )
    modelDownloader.listDownloadedModels { result in
      completionExpectation.fulfill()
      switch result {
      case let .success(models):
        /// Expected success since model info was written to user defaults.
        XCTAssertEqual(models.first?.path, tempModelFileURL.path)
      case let .failure(error):
        XCTFail("Error - \(error)")
      }
    }
    wait(for: [completionExpectation], timeout: 0.5)
    try? ModelFileManager.removeFile(at: tempModelFileURL)
  }

  /// Test invalid path in model directory
  func testListModelsInvalidPath() {
    let modelDownloader = ModelDownloader.modelDownloader()
    let invalidTempModelFileURL = tempModelFile(invalid: true)
    let completionExpectation = expectation(description: "Completion handler")

    modelDownloader.listDownloadedModels { result in
      completionExpectation.fulfill()
      switch result {
      case .success:
        XCTFail("Unexpected success of list models.")
      case let .failure(error):
        switch error {
        case let .internalError(description):
          XCTAssertTrue(description
            .contains("List models failed due to unexpected model file name"))
        default: XCTFail("Expected failure due to bad model name.")
        }
      }
    }
    wait(for: [completionExpectation], timeout: 0.5)
    try? ModelFileManager.removeFile(at: invalidTempModelFileURL)
  }

  /// Test listing models without local info in user defaults.
  func testListModelsNoLocalInfo() {
    guard let testApp = FirebaseApp.app() else {
      XCTFail("Default app was not configured.")
      return
    }

    let tempModelFileURL = tempModelFile()
    let modelDownloader = ModelDownloader.modelDownloaderWithDefaults(
      .createTestInstance(testName: #function),
      app: testApp
    )

    let completionExpectation = expectation(description: "Completion handler")

    modelDownloader.listDownloadedModels { result in
      completionExpectation.fulfill()
      switch result {
      case .success:
        XCTFail("Unexpected success of list models.")
      case let .failure(error):
        switch error {
        /// Expected failure since no model info was written to user defaults.
        case let .internalError(description):
          XCTAssertTrue(description.contains("List models failed due to no local model info"))
        default: XCTFail("Expected failure due to bad model name.")
        }
      }
    }
    wait(for: [completionExpectation], timeout: 0.5)
    try? ModelFileManager.removeFile(at: tempModelFileURL)
  }

  /// Test how URL conversion behaves if there are spaces in the path.
  func testURLConversion() {
    /// Spaces in the string only convert to URL when using URL(fileURLWithPath: ).
    let fakeURLWithSpace = URL(string: "file:///fakeDir1/fake%20Dir2/fakeFile")!

    XCTAssertEqual(fakeURLWithSpace, URL(string: fakeURLWithSpace.absoluteString))
    XCTAssertEqual(fakeURLWithSpace, URL(fileURLWithPath: fakeURLWithSpace.path))
    XCTAssertNil(URL(string: fakeURLWithSpace.path))

    /// Strings without spaces should work fine either way.
    let fakeURLWithoutSpace = URL(string: "fakeDir1/fakeDir2/fakeFile")!
    XCTAssertEqual(fakeURLWithoutSpace, URL(string: fakeURLWithoutSpace.absoluteString)!)
    XCTAssertEqual(fakeURLWithoutSpace, URL(string: fakeURLWithoutSpace.path)!)
  }

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

  /// Test on-device logging.
  func testDeviceLogging() {
    DeviceLogger.logEvent(level: .error,
                          message: "This is a test error logged to device.",
                          messageCode: .testError)
  }

  /// Compare proto serialization methods.
  func testTelemetryEncoding() {
    let fakeModel = CustomModel(
      name: fakeModelName,
      size: 10,
      path: fakeModelPath,
      hash: fakeModelHash
    )
    var modelOptions = ModelOptions()
    modelOptions.setModelOptions(model: fakeModel)

    guard let binaryData = try? modelOptions.serializedData(),
      let jsonData = try? modelOptions.jsonUTF8Data(),
      let binaryEvent = try? ModelOptions(serializedData: binaryData),
      let jsonEvent = try? ModelOptions(jsonUTF8Data: jsonData) else {
      XCTFail("Encoding error.")
      return
    }

    XCTAssertNotNil(binaryData)
    XCTAssertNotNil(jsonData)
    XCTAssertLessThan(binaryData.count, jsonData.count)
    XCTAssertEqual(binaryEvent, jsonEvent)
  }

  /// Get model info if server returns a new model info.
  func testGetModelInfoWith200() {
    let session = fakeModelInfoSessionWithURL(fakeDownloadURL, statusCode: 200)
    let modelInfoRetriever = fakeModelRetriever(fakeSession: session)
    let completionExpectation = expectation(description: "Completion handler")

    modelInfoRetriever.downloadModelInfo { result in
      completionExpectation.fulfill()
      switch result {
      case let .success(fakemodelInfoResult):
        switch fakemodelInfoResult {
        case let .modelInfo(remoteModelInfo):
          XCTAssertEqual(remoteModelInfo.name, self.fakeModelName)
          XCTAssertEqual(remoteModelInfo.downloadURL, self.fakeDownloadURL)
          XCTAssertEqual(remoteModelInfo.size, self.fakeModelSize)
          XCTAssertEqual(remoteModelInfo.modelHash, self.fakeModelHash)
        case .notModified: XCTFail("Expected new model info from server.")
        }
      case let .failure(error): XCTFail("Failed with error - \(error)")
      }
    }
    wait(for: [completionExpectation], timeout: 0.5)
  }

  /// Get model info if model info is not modified.
  func testGetModelInfoWith304() {
    let session = fakeModelInfoSessionWithURL(fakeDownloadURL, statusCode: 304)
    let localModelInfo = fakeLocalModelInfo(mismatch: false)
    let modelInfoRetriever = fakeModelRetriever(
      fakeSession: session,
      fakeLocalModelInfo: localModelInfo
    )
    let completionExpectation = expectation(description: "Completion handler")

    modelInfoRetriever.downloadModelInfo { result in
      completionExpectation.fulfill()
      switch result {
      case let .success(fakemodelInfoResult):
        switch fakemodelInfoResult {
        case .modelInfo: XCTFail("Unexpected new model info from server.")
        case .notModified: break
        }
      case let .failure(error): XCTFail("Failed with error - \(error)")
      }
    }
    wait(for: [completionExpectation], timeout: 0.5)
  }

  /// Get model info if model info is not modified but local model info is not set.
  func testGetModelInfoWith304MissingLocalInfo() {
    let session = fakeModelInfoSessionWithURL(fakeDownloadURL, statusCode: 304)
    let modelInfoRetriever = fakeModelRetriever(fakeSession: session)
    let completionExpectation = expectation(description: "Completion handler")

    modelInfoRetriever.downloadModelInfo { result in
      completionExpectation.fulfill()
      switch result {
      case let .success(fakemodelInfoResult):
        switch fakemodelInfoResult {
        case .modelInfo: XCTFail("Unexpected new model info from server.")
        case .notModified: XCTFail("Expected failure since local model info was not set.")
        }
      case let .failure(error):
        switch error {
        case let .internalError(description: errorMessage): XCTAssertEqual(errorMessage,
                                                                           "Model info was deleted unexpectedly.")
        default: XCTFail("Expected failure since local model info was not set.")
        }
      }
    }
    wait(for: [completionExpectation], timeout: 0.5)
  }

  /// Get model info if model info is not modified but local model info is not set.
  func testGetModelInfoWith304HashMismatch() {
    let session = fakeModelInfoSessionWithURL(fakeDownloadURL, statusCode: 304)
    let localModelInfo = fakeLocalModelInfo(mismatch: true)
    let modelInfoRetriever = fakeModelRetriever(
      fakeSession: session,
      fakeLocalModelInfo: localModelInfo
    )
    let completionExpectation = expectation(description: "Completion handler")

    modelInfoRetriever.downloadModelInfo { result in
      completionExpectation.fulfill()
      switch result {
      case let .success(fakemodelInfoResult):
        switch fakemodelInfoResult {
        case .modelInfo: XCTFail("Unexpected new model info from server.")
        case .notModified: XCTFail("Expected failure since model hash does not match.")
        }
      case let .failure(error):
        switch error {
        case let .internalError(description: errorMessage): XCTAssertEqual(errorMessage,
                                                                           "Unexpected model hash value.")
        default: XCTFail("Expected failure since local model info was not set.")
        }
      }
    }
    wait(for: [completionExpectation], timeout: 0.5)
  }

  /// Get model info if model name is invalid.
  func testGetModelInfoWith400() {
    let session = fakeModelInfoSessionWithURL(fakeDownloadURL, statusCode: 400)
    let localModelInfo = fakeLocalModelInfo(mismatch: false)
    let modelInfoRetriever = fakeModelRetriever(
      fakeSession: session,
      fakeLocalModelInfo: localModelInfo
    )
    let completionExpectation = expectation(description: "Completion handler")

    modelInfoRetriever.downloadModelInfo { result in
      completionExpectation.fulfill()
      switch result {
      case let .success(fakemodelInfoResult):
        switch fakemodelInfoResult {
        case .modelInfo: XCTFail("Unexpected new model info from server.")
        case .notModified: XCTFail("Expected failure since model name is invalid.")
        }
      case let .failure(error):
        XCTAssertEqual(error, .invalidArgument)
      }
    }
    wait(for: [completionExpectation], timeout: 0.5)
  }

  /// Get model if server returns a model file.
  func testModelDownloadWith200() {
    let tempFileURL = tempFile()
    let remoteModelInfo = fakeModelInfo(expired: false, oversized: false)
    let fakeResponse = HTTPURLResponse(url: fakeFileURL,
                                       statusCode: 200,
                                       httpVersion: nil,
                                       headerFields: nil)!
    let downloader = MockModelFileDownloader()
    let fileDownloaderExpectation = expectation(description: "File downloader")
    downloader.downloadFileHandler = { url in
      fileDownloaderExpectation.fulfill()
      XCTAssertEqual(url, self.fakeDownloadURL)
    }
    let progressExpectation = expectation(description: "Progress handler")
    progressExpectation.expectedFulfillmentCount = 2

    let completionExpectation = expectation(description: "Completion handler")
    let modelDownloadTask = ModelDownloadTask(remoteModelInfo: remoteModelInfo,
                                              appName: fakeAppName,
                                              defaults: .createTestInstance(testName: #function),
                                              downloader: downloader)

    modelDownloadTask.download(progressHandler: {
      progress in
      progressExpectation.fulfill()
      XCTAssertEqual(progress, 0.4)
    }) { result in
      completionExpectation.fulfill()
      switch result {
      case let .success(model):
        XCTAssertEqual(model.name, self.fakeModelName)
        XCTAssertEqual(model.size, self.fakeModelSize)
        XCTAssertEqual(model.hash, self.fakeModelHash)
        let modelPath = URL(fileURLWithPath: model.path)
        XCTAssertTrue(ModelFileManager.isFileReachable(at: modelPath))
        try? self.deleteFile(at: modelPath)
      case let .failure(error):
        XCTFail("Error - \(error)")
      }
    }
    wait(for: [fileDownloaderExpectation], timeout: 0.1)

    downloader.progressHandler?(100, 250)
    downloader.progressHandler?(100, 250)
    wait(for: [progressExpectation], timeout: 0.5)

    downloader
      .completion?(.success(FileDownloaderResponse(urlResponse: fakeResponse,
                                                   fileURL: tempFileURL)))
    wait(for: [completionExpectation], timeout: 0.5)

    try? ModelFileManager.removeFile(at: tempFileURL)
  }

  /// Get model if server returns an error due to expired url.
  func testModelDownloadWith400Expired() {
    let tempFileURL = tempFile()
    let remoteModelInfo = fakeModelInfo(expired: true, oversized: false)
    let fakeResponse = HTTPURLResponse(url: fakeFileURL,
                                       statusCode: 400,
                                       httpVersion: nil,
                                       headerFields: nil)!
    let downloader = MockModelFileDownloader()
    let fileDownloaderExpectation = expectation(description: "File downloader")
    downloader.downloadFileHandler = { url in
      fileDownloaderExpectation.fulfill()
      XCTAssertEqual(url, self.fakeDownloadURL)
    }

    let completionExpectation = expectation(description: "Completion handler")
    let modelDownloadTask = ModelDownloadTask(remoteModelInfo: remoteModelInfo,
                                              appName: fakeAppName,
                                              defaults: .createTestInstance(testName: #function),
                                              downloader: downloader)
    modelDownloadTask.download(progressHandler: nil) { result in
      completionExpectation.fulfill()
      switch result {
      case .success: XCTFail("Unexpected successful model download.")
      case let .failure(error):
        XCTAssertEqual(error, .expiredDownloadURL)
      }
    }
    wait(for: [fileDownloaderExpectation], timeout: 0.1)

    downloader
      .completion?(.success(FileDownloaderResponse(urlResponse: fakeResponse,
                                                   fileURL: tempFileURL)))
    wait(for: [completionExpectation], timeout: 0.5)

    try? ModelFileManager.removeFile(at: tempFileURL)
  }

  /// Get model if server returns an error due to invalid model name.
  func testModelDownloadWith400Invalid() {
    let tempFileURL = tempFile()
    let remoteModelInfo = fakeModelInfo(expired: false, oversized: false)
    let fakeResponse = HTTPURLResponse(url: fakeFileURL,
                                       statusCode: 400,
                                       httpVersion: nil,
                                       headerFields: nil)!
    let downloader = MockModelFileDownloader()
    let fileDownloaderExpectation = expectation(description: "File downloader")
    downloader.downloadFileHandler = { url in
      fileDownloaderExpectation.fulfill()
      XCTAssertEqual(url, self.fakeDownloadURL)
    }

    let completionExpectation = expectation(description: "Completion handler")
    let modelDownloadTask = ModelDownloadTask(remoteModelInfo: remoteModelInfo,
                                              appName: fakeAppName,
                                              defaults: .createTestInstance(testName: #function),
                                              downloader: downloader)
    modelDownloadTask.download(progressHandler: nil) { result in
      completionExpectation.fulfill()
      switch result {
      case .success: XCTFail("Unexpected successful model download.")
      case let .failure(error):
        XCTAssertEqual(error, .invalidArgument)
      }
    }
    wait(for: [fileDownloaderExpectation], timeout: 0.1)

    downloader
      .completion?(.success(FileDownloaderResponse(urlResponse: fakeResponse,
                                                   fileURL: tempFileURL)))
    wait(for: [completionExpectation], timeout: 0.5)

    try? ModelFileManager.removeFile(at: tempFileURL)
  }

  /// Get model if server returns an error due to model not found.
  func testModelDownloadWith404() {
    let tempFileURL = tempFile()
    let remoteModelInfo = fakeModelInfo(expired: false, oversized: false)
    let fakeResponse = HTTPURLResponse(url: fakeFileURL,
                                       statusCode: 404,
                                       httpVersion: nil,
                                       headerFields: nil)!
    let downloader = MockModelFileDownloader()
    let fileDownloaderExpectation = expectation(description: "File downloader")
    downloader.downloadFileHandler = { url in
      fileDownloaderExpectation.fulfill()
      XCTAssertEqual(url, self.fakeDownloadURL)
    }

    let completionExpectation = expectation(description: "Completion handler")
    let modelDownloadTask = ModelDownloadTask(remoteModelInfo: remoteModelInfo,
                                              appName: fakeAppName,
                                              defaults: .createTestInstance(testName: #function),
                                              downloader: downloader)
    modelDownloadTask.download(progressHandler: nil) { result in
      completionExpectation.fulfill()
      switch result {
      case .success: XCTFail("Unexpected successful model download.")
      case let .failure(error):
        XCTAssertEqual(error, .notFound)
      }
    }
    wait(for: [fileDownloaderExpectation], timeout: 0.1)

    downloader
      .completion?(.success(FileDownloaderResponse(urlResponse: fakeResponse,
                                                   fileURL: tempFileURL)))
    wait(for: [completionExpectation], timeout: 0.5)

    try? ModelFileManager.removeFile(at: tempFileURL)
  }

  /// Get model if download url expired but retry was successful.
  func testGetModelSuccessfulRetry() {
    let modelDownloader = ModelDownloader.modelDownloader()
    let conditions = ModelDownloadConditions()
    let session = fakeModelInfoSessionWithURL(fakeDownloadURL, statusCode: 200)
    let modelInfoRetriever = fakeModelRetriever(fakeSession: session)
    let downloader = MockModelFileDownloader()
    let tempFileURL = tempFile()

    let fakeResponseExpired = HTTPURLResponse(url: fakeFileURL,
                                              statusCode: 400,
                                              httpVersion: nil,
                                              headerFields: nil)!

    let fakeResponseSucceeded = HTTPURLResponse(url: fakeFileURL,
                                                statusCode: 200,
                                                httpVersion: nil,
                                                headerFields: nil)!

    let fileDownloaderExpectation1 = expectation(description: "File downloader before retry")
    let completionExpectation = expectation(description: "Completion handler.")

    // Handles initial response.
    downloader.downloadFileHandler = { url in
      fileDownloaderExpectation1.fulfill()
      XCTAssertEqual(url, self.fakeDownloadURL)
    }

    modelDownloader.downloadInfoAndModel(modelName: fakeModelName,
                                         modelInfoRetriever: modelInfoRetriever,
                                         downloader: downloader,
                                         conditions: conditions) { result in
      completionExpectation.fulfill()
      switch result {
      // Retry successful - model returned.
      case let .success(model):
        XCTAssertEqual(model.name, self.fakeModelName)
        XCTAssertEqual(model.size, self.fakeModelSize)
        XCTAssertEqual(model.hash, self.fakeModelHash)
        let modelPath = URL(fileURLWithPath: model.path)
        XCTAssertTrue(ModelFileManager.isFileReachable(at: modelPath))
        try? self.deleteFile(at: modelPath)
      case let .failure(error):
        XCTFail("Error - \(error)")
      }
    }
    wait(for: [fileDownloaderExpectation1], timeout: 0.5)

    // Handles response after one retry.
    let fileDownloaderExpectation2 = expectation(description: "File downloader after retry")
    downloader.downloadFileHandler = { url in
      fileDownloaderExpectation2.fulfill()
      XCTAssertEqual(url, self.fakeDownloadURL)
    }
    downloader
      .completion?(.success(FileDownloaderResponse(urlResponse: fakeResponseExpired,
                                                   fileURL: tempFileURL)))
    wait(for: [fileDownloaderExpectation2], timeout: 0.5)

    downloader
      .completion?(.success(FileDownloaderResponse(urlResponse: fakeResponseSucceeded,
                                                   fileURL: tempFileURL)))
    wait(for: [completionExpectation], timeout: 0.5)

    try? ModelFileManager.removeFile(at: tempFileURL)
  }

  /// Get model if model doesn't exist.
  func testGetModelNotFound() {
    let modelDownloader = ModelDownloader.modelDownloader()
    let conditions = ModelDownloadConditions()
    let session = fakeModelInfoSessionWithURL(fakeDownloadURL, statusCode: 200)
    let modelInfoRetriever = fakeModelRetriever(fakeSession: session)
    let downloader = MockModelFileDownloader()
    let tempFileURL = tempFile()

    let fakeResponseNotFound = HTTPURLResponse(url: fakeFileURL,
                                               statusCode: 404,
                                               httpVersion: nil,
                                               headerFields: nil)!

    let fileDownloaderExpectation = expectation(description: "File downloader before retry")
    let completionExpectation = expectation(description: "Completion handler")

    // Handles initial response.
    downloader.downloadFileHandler = { url in
      fileDownloaderExpectation.fulfill()
      XCTAssertEqual(url, self.fakeDownloadURL)
    }

    modelDownloader.downloadInfoAndModel(modelName: fakeModelName,
                                         modelInfoRetriever: modelInfoRetriever,
                                         downloader: downloader,
                                         conditions: conditions) { result in
      completionExpectation.fulfill()
      switch result {
      // Retry failed due to another expired url - error returned.
      case .success: XCTFail("Unexpected successful model download.")
      case let .failure(error):
        switch error {
        case .notFound: break
        default: XCTFail("Expected failure due to model not found.")
        }
      }
    }
    wait(for: [fileDownloaderExpectation], timeout: 0.5)

    downloader
      .completion?(.success(FileDownloaderResponse(urlResponse: fakeResponseNotFound,
                                                   fileURL: tempFileURL)))
    wait(for: [completionExpectation], timeout: 0.5)

    try? ModelFileManager.removeFile(at: tempFileURL)
  }

  /// Get model if invalid or insufficient permissions.
  func testGetModelUnauthorized() {
    let modelDownloader = ModelDownloader.modelDownloader()
    let conditions = ModelDownloadConditions()
    let session = fakeModelInfoSessionWithURL(fakeDownloadURL, statusCode: 200)
    let modelInfoRetriever = fakeModelRetriever(fakeSession: session)
    let downloader = MockModelFileDownloader()
    let tempFileURL = tempFile()

    let fakeResponseNotFound = HTTPURLResponse(url: fakeFileURL,
                                               statusCode: 403,
                                               httpVersion: nil,
                                               headerFields: nil)!

    let fileDownloaderExpectation = expectation(description: "File downloader before retry")
    let completionExpectation = expectation(description: "Completion handler")

    // Handles initial response.
    downloader.downloadFileHandler = { url in
      fileDownloaderExpectation.fulfill()
      XCTAssertEqual(url, self.fakeDownloadURL)
    }

    modelDownloader.downloadInfoAndModel(modelName: fakeModelName,
                                         modelInfoRetriever: modelInfoRetriever,
                                         downloader: downloader,
                                         conditions: conditions) { result in
      completionExpectation.fulfill()
      switch result {
      // Retry failed due to another expired url - error returned.
      case .success: XCTFail("Unexpected successful model download.")
      case let .failure(error):
        switch error {
        case .permissionDenied: break
        default: XCTFail("Expected failure due to bad permissions.")
        }
      }
    }
    wait(for: [fileDownloaderExpectation], timeout: 0.5)

    downloader
      .completion?(.success(FileDownloaderResponse(urlResponse: fakeResponseNotFound,
                                                   fileURL: tempFileURL)))
    wait(for: [completionExpectation], timeout: 0.5)

    try? ModelFileManager.removeFile(at: tempFileURL)
  }

  /// Get model if download url expired and retry url also expired.
  func testGetModelFailedRetry() {
    let modelDownloader = ModelDownloader.modelDownloader()
    let conditions = ModelDownloadConditions()
    let session = fakeModelInfoSessionWithURL(fakeDownloadURL, statusCode: 200)
    let modelInfoRetriever = fakeModelRetriever(fakeSession: session)
    let downloader = MockModelFileDownloader()
    let tempFileURL = tempFile()

    let fakeResponseExpired = HTTPURLResponse(url: fakeFileURL,
                                              statusCode: 400,
                                              httpVersion: nil,
                                              headerFields: nil)!

    let fileDownloaderExpectation1 = expectation(description: "File downloader before retry")
    let completionExpectation = expectation(description: "Completion handler")

    // Handles initial response.
    downloader.downloadFileHandler = { url in
      fileDownloaderExpectation1.fulfill()
      XCTAssertEqual(url, self.fakeDownloadURL)
    }

    modelDownloader.downloadInfoAndModel(modelName: fakeModelName,
                                         modelInfoRetriever: modelInfoRetriever,
                                         downloader: downloader,
                                         conditions: conditions) { result in
      completionExpectation.fulfill()
      switch result {
      // Retry failed due to another expired url - error returned.
      case .success: XCTFail("Unexpected successful model download.")
      case let .failure(error):
        switch error {
        case let .internalError(description: errorMessage): XCTAssertEqual(errorMessage,
                                                                           "Unable to update expired model info.")
        default: XCTFail("Expected failure due to expired model info.")
        }
      }
    }
    wait(for: [fileDownloaderExpectation1], timeout: 0.5)

    let fileDownloaderExpectation2 = expectation(description: "File downloader after retry")
    // Handles response after one retry.
    downloader.downloadFileHandler = { url in
      fileDownloaderExpectation2.fulfill()
      XCTAssertEqual(url, self.fakeDownloadURL)
    }
    downloader
      .completion?(.success(FileDownloaderResponse(urlResponse: fakeResponseExpired,
                                                   fileURL: tempFileURL)))
    wait(for: [fileDownloaderExpectation2], timeout: 0.5)

    downloader
      .completion?(.success(FileDownloaderResponse(urlResponse: fakeResponseExpired,
                                                   fileURL: tempFileURL)))
    wait(for: [completionExpectation], timeout: 0.5)

    try? ModelFileManager.removeFile(at: tempFileURL)
  }

  /// Get model if multiple retries all returned expired urls.
  func testGetModelMultipleFailedRetries() {
    let modelDownloader = ModelDownloader.modelDownloader()
    modelDownloader.numberOfRetries = 2
    let conditions = ModelDownloadConditions()
    let session = fakeModelInfoSessionWithURL(fakeDownloadURL, statusCode: 200)
    let modelInfoRetriever = fakeModelRetriever(fakeSession: session)
    let downloader = MockModelFileDownloader()
    let tempFileURL = tempFile()

    let fakeResponseExpired = HTTPURLResponse(url: fakeFileURL,
                                              statusCode: 400,
                                              httpVersion: nil,
                                              headerFields: nil)!

    let fileDownloaderExpectation1 = expectation(description: "File downloader before retry")
    let completionExpectation = expectation(description: "Completion handler")

    // Handles initial response.
    downloader.downloadFileHandler = { url in
      fileDownloaderExpectation1.fulfill()
      XCTAssertEqual(url, self.fakeDownloadURL)
    }

    modelDownloader.downloadInfoAndModel(modelName: fakeModelName,
                                         modelInfoRetriever: modelInfoRetriever,
                                         downloader: downloader,
                                         conditions: conditions) { result in
      completionExpectation.fulfill()
      switch result {
      // Two retries failed due to expired urls - error returned.
      case .success: XCTFail("Unexpected successful model download.")
      case let .failure(error):
        switch error {
        case let .internalError(description: errorMessage): XCTAssertEqual(errorMessage,
                                                                           "Unable to update expired model info.")
        default: XCTFail("Expected failure due to expired model info.")
        }
      }
    }
    wait(for: [fileDownloaderExpectation1], timeout: 0.5)

    let fileDownloaderExpectation2 = expectation(description: "file downloader after first retry")
    // Handles response after first retry.
    downloader.downloadFileHandler = { url in
      fileDownloaderExpectation2.fulfill()
      XCTAssertEqual(url, self.fakeDownloadURL)
    }
    downloader
      .completion?(.success(FileDownloaderResponse(urlResponse: fakeResponseExpired,
                                                   fileURL: tempFileURL)))
    wait(for: [fileDownloaderExpectation2], timeout: 0.5)

    let fileDownloaderExpectation3 = expectation(description: "File downloader after second retry")
    // Handles response after second retry.
    downloader.downloadFileHandler = { url in
      fileDownloaderExpectation3.fulfill()
      XCTAssertEqual(url, self.fakeDownloadURL)
    }
    downloader
      .completion?(.success(FileDownloaderResponse(urlResponse: fakeResponseExpired,
                                                   fileURL: tempFileURL)))
    wait(for: [fileDownloaderExpectation3], timeout: 0.5)

    downloader
      .completion?(.success(FileDownloaderResponse(urlResponse: fakeResponseExpired,
                                                   fileURL: tempFileURL)))
    wait(for: [completionExpectation], timeout: 0.5)

    try? ModelFileManager.removeFile(at: tempFileURL)
  }

  /// Get model if a retry finally returns an unexpired download url.
  func testGetModelMultipleRetriesWithSuccess() {
    let modelDownloader = ModelDownloader.modelDownloader()
    modelDownloader.numberOfRetries = 4
    let conditions = ModelDownloadConditions()
    let session = fakeModelInfoSessionWithURL(fakeDownloadURL, statusCode: 200)
    let modelInfoRetriever = fakeModelRetriever(fakeSession: session)
    let downloader = MockModelFileDownloader()
    let tempFileURL = tempFile()

    let fakeResponseExpired = HTTPURLResponse(url: fakeFileURL,
                                              statusCode: 400,
                                              httpVersion: nil,
                                              headerFields: nil)!

    let fakeResponseSucceeded = HTTPURLResponse(url: fakeFileURL,
                                                statusCode: 200,
                                                httpVersion: nil,
                                                headerFields: nil)!

    let fileDownloaderExpectation1 = expectation(description: "File downloader before retry")
    let completionExpectation = expectation(description: "Completion handler")

    // Handles initial response.
    downloader.downloadFileHandler = { url in
      fileDownloaderExpectation1.fulfill()
      XCTAssertEqual(url, self.fakeDownloadURL)
    }

    modelDownloader.downloadInfoAndModel(modelName: fakeModelName,
                                         modelInfoRetriever: modelInfoRetriever,
                                         downloader: downloader,
                                         conditions: conditions) { result in
      completionExpectation.fulfill()
      switch result {
      // One retry failed but the next retry succeeded - model returned.
      case let .success(model):
        XCTAssertEqual(model.name, self.fakeModelName)
        XCTAssertEqual(model.size, self.fakeModelSize)
        XCTAssertEqual(model.hash, self.fakeModelHash)
        let modelPath = URL(fileURLWithPath: model.path)
        XCTAssertTrue(ModelFileManager.isFileReachable(at: modelPath))
        try? self.deleteFile(at: modelPath)
      case let .failure(error):
        XCTFail("Error - \(error)")
      }
    }
    wait(for: [fileDownloaderExpectation1], timeout: 0.5)

    let fileDownloaderExpectation2 = expectation(description: "File downloader after first retry")
    // Handles response after first retry.
    downloader.downloadFileHandler = { url in
      fileDownloaderExpectation2.fulfill()
      XCTAssertEqual(url, self.fakeDownloadURL)
    }
    downloader
      .completion?(.success(FileDownloaderResponse(urlResponse: fakeResponseExpired,
                                                   fileURL: tempFileURL)))
    wait(for: [fileDownloaderExpectation2], timeout: 0.5)

    let fileDownloaderExpectation3 = expectation(description: "File downloader after second retry")
    // Handles response after second retry.
    downloader.downloadFileHandler = { url in
      fileDownloaderExpectation3.fulfill()
      XCTAssertEqual(url, self.fakeDownloadURL)
    }
    downloader
      .completion?(.success(FileDownloaderResponse(urlResponse: fakeResponseExpired,
                                                   fileURL: tempFileURL)))
    wait(for: [fileDownloaderExpectation3], timeout: 0.5)

    downloader
      .completion?(.success(FileDownloaderResponse(urlResponse: fakeResponseSucceeded,
                                                   fileURL: tempFileURL)))
    wait(for: [completionExpectation], timeout: 0.5)

    try? ModelFileManager.removeFile(at: tempFileURL)
  }
}

/// Mock URL session for testing.
class MockModelInfoRetrieverSession: ModelInfoRetrieverSession {
  var data: Data?
  var response: URLResponse?
  var error: Error?

  func getModelInfo(with request: URLRequest,
                    completion: @escaping (Data?, URLResponse?, Error?) -> Void) {
    completion(data, response, error)
  }
}

class MockModelFileDownloader: FileDownloader {
  var progressHandler: ProgressHandler?
  var completion: CompletionHandler?
  var downloadFileHandler: ((_ url: URL) -> Void)?

  func downloadFile(with url: URL, progressHandler: @escaping ProgressHandler,
                    completion: @escaping CompletionHandler) {
    self.progressHandler = progressHandler
    self.completion = completion
    downloadFileHandler?(url)
  }
}

extension UserDefaults {
  /// Returns a new cleared instance of user defaults.
  static func createTestInstance(testName: String) -> UserDefaults {
    let suiteName = "com.google.firebase.ml.test.\(testName)"
    // TODO: reconsider force unwrapping
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
  }

  /// Returns the existing user defaults instance.
  static func getTestInstance(testName: String) -> UserDefaults {
    let suiteName = "com.google.firebase.ml.test.\(testName)"
    // TODO: reconsider force unwrapping
    return UserDefaults(suiteName: suiteName)!
  }
}

// MARK: - Helpers

extension ModelDownloaderUnitTests {
  func fakeModelInfoSessionWithURL(_ url: URL, statusCode: Int) -> MockModelInfoRetrieverSession {
    let fakeSession = MockModelInfoRetrieverSession()
    fakeSession.data = fakeModelJSON.data(using: .utf8)
    fakeSession.response = HTTPURLResponse(
      url: url,
      statusCode: statusCode,
      httpVersion: nil,
      headerFields: ["Etag": "fakeModelHash"]
    )
    fakeSession.error = nil
    return fakeSession
  }

  func fakeModelRetriever(fakeSession: MockModelInfoRetrieverSession,
                          fakeLocalModelInfo: LocalModelInfo? = nil) -> ModelInfoRetriever {
    // TODO: Replace with a fake one so we can check that is was used correctly by the download task.
    let modelInfoRetriever = ModelInfoRetriever(
      modelName: fakeModelName,
      projectID: fakeProjectID,
      apiKey: fakeAPIKey,
      authTokenProvider: successAuthTokenProvider,
      appName: fakeAppName,
      localModelInfo: fakeLocalModelInfo,
      session: fakeSession
    )
    return modelInfoRetriever
  }

  func tempFile() -> URL {
    let tempDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory(),
                               isDirectory: true)
    let tempFileURL = tempDirectoryURL.appendingPathComponent("fake-model-file.tmp")
    let tempData: Data = "fakeModelData".data(using: .utf8)!
    try? tempData.write(to: tempFileURL)
    return tempFileURL
  }

  func tempModelFile(invalid: Bool = false) -> URL {
    let modelDirectoryURL = ModelFileManager.modelsDirectory
    let modelFileName = invalid ? "fake-model-file.tmp" :
      "fbml_model@@__FIRAPP_DEFAULT@@\(fakeModelName)"
    let tempFileURL = modelDirectoryURL.appendingPathComponent(modelFileName)
    let tempData: Data = "fakeModelData".data(using: .utf8)!
    try? tempData.write(to: tempFileURL)
    return tempFileURL
  }

  func deleteFile(at url: URL) throws {
    try ModelFileManager.removeFile(at: url)
  }

  func fakeLocalModelInfo(mismatch: Bool = false) -> LocalModelInfo {
    let hash = mismatch ? "wrongModelHash" : fakeModelHash
    return LocalModelInfo(
      name: fakeModelName,
      modelHash: hash,
      size: 20
    )
  }

  func fakeModelInfo(expired: Bool, oversized: Bool) -> RemoteModelInfo {
    let expiryTime = expired ? Date() : Date().addingTimeInterval(1000)
    let size = oversized ? Int(Int64.max) / 4 : fakeModelSize
    return RemoteModelInfo(name: fakeModelName,
                           downloadURL: fakeDownloadURL,
                           modelHash: fakeModelHash,
                           size: size,
                           urlExpiryTime: expiryTime)
  }
}
