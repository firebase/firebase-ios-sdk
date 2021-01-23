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

  /// Test model file deletion.
  // TODO: Add unit test.
  func testDeleteModel() {}

  /// Test listing models in model directory.
  // TODO: Add unit test.
  func testListModels() {
    let modelDownloader = ModelDownloader.modelDownloader()

    modelDownloader.listDownloadedModels { result in
      switch result {
      case .success: break
      case .failure: break
      }
    }
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

  /// Compare proto serialization methods.
  func testTelemetryEncoding() {
    let fakeModel = CustomModel(
      name: "fakeModelName",
      size: 10,
      path: "fakeModelPath",
      hash: "fakeModelHash"
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
}

/// Unit tests for network calls.
class NetworkingUnitTests: XCTestCase {
  let fakeModelName = "fakeModelName"
  let fakeModelHash = "fakeModelHash"
  let fakeDownloadURL = URL(string: "www.fake-download-url.com")!
  let fakeFileURL = URL(string: "www.fake-model-file.com")!
  let fakeExpiryTime = "2021-01-20T04:20:10.220Z"
  let fakeModelSize = 20
  let fakeProjectID = "fakeProjectID"
  let fakeAPIKey = "fakeAPIKey"
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
  }

  /// Get model info if server returns a new model info.
  func testGetModelInfoWith200() {
    let session = fakeModelInfoSessionWithURL(fakeDownloadURL, statusCode: 200)
    let modelInfoRetriever = fakeModelRetriever(fakeSession: session)
    let completionExpectation = expectation(description: "completion handler")

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
    let localModelInfo = fakeLocalModelInfo()
    let modelInfoRetriever = fakeModelRetriever(
      fakeSession: session,
      fakeLocalModelInfo: localModelInfo
    )
    let completionExpectation = expectation(description: "completion handler")

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
  func testGetModelInfoWith304Invalid() {
    let session = fakeModelInfoSessionWithURL(fakeDownloadURL, statusCode: 304)
    let modelInfoRetriever = fakeModelRetriever(fakeSession: session)
    let completionExpectation = expectation(description: "completion handler")

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

  func testModelDownloadWith200() {
    let session = fakeModelInfoSessionWithURL(fakeDownloadURL, statusCode: 200)
    let modelInfoRetriever = fakeModelRetriever(fakeSession: session)
    let tempFileURL = tempFile()
    let remoteModelInfo = fakeModelInfo()

    let fakeResponse = HTTPURLResponse(url: fakeFileURL,
                                       statusCode: 200,
                                       httpVersion: nil,
                                       headerFields: nil)!

    // Expect file downloader to be called.
    let downloader = MockModelFileDownloader()
    let fileDownloaderExpectation = expectation(description: "file downloader")
    downloader.downloadFileHandler = { url in
      fileDownloaderExpectation.fulfill()
      XCTAssertEqual(url, self.fakeDownloadURL)
    }

    // Create task and set up progress and completion expectations.
    let progressExpectation = expectation(description: "progress handler")
    progressExpectation.expectedFulfillmentCount = 2
    let completionExpectation = expectation(description: "completion handler")

    let modelDownloadTask = ModelDownloadTask(remoteModelInfo: remoteModelInfo,
                                              appName: "fakeAppName",
                                              defaults: .createTestInstance(testName: #function),
                                              downloader: downloader,
                                              modelInfoRetriever: modelInfoRetriever,
                                              progressHandler: {
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
        XCTAssertTrue(ModelFileManager.isFileReachable(at: URL(string: model.path)!))
      case let .failure(error):
        XCTFail("Error - \(error)")
      }
    }

    modelDownloadTask.download()

    // Wait for downloader to be called.
    wait(for: [fileDownloaderExpectation], timeout: 0.1)

    // Call downloader progress handler and wait for task progress handler to be called.
    downloader.progressHandler?(100, 250)
    // Call a second time as we expect the task progress handler to be called twice.
    downloader.progressHandler?(100, 250)
    wait(for: [progressExpectation], timeout: 0.5)

    // Call download completion and wait for task completion.
    downloader
      .completion?(.success(FileDownloaderResponse(urlResponse: fakeResponse,
                                                   fileURL: tempFileURL)))

    wait(for: [completionExpectation], timeout: 0.5)

    // Cleanup temp file.
    try? ModelFileManager.removeFile(at: tempFileURL)
  }

  func testModelDownloadWithSuccessfulRetry() {
    let session = fakeModelInfoSessionWithURL(fakeDownloadURL, statusCode: 200)
    let modelInfoRetriever = fakeModelRetriever(fakeSession: session)
    let tempFileURL = tempFile()
    let remoteModelInfo = fakeModelInfo()

    var fakeResponse = HTTPURLResponse(url: fakeFileURL,
                                       statusCode: 400,
                                       httpVersion: nil,
                                       headerFields: nil)!

    // Expect file downloader to be called.
    let downloader = MockModelFileDownloader()
    let fileDownloaderExpectation = expectation(description: "file downloader")

    downloader.downloadFileHandler = { url in
      fileDownloaderExpectation.fulfill()
      XCTAssertEqual(url, self.fakeDownloadURL)
      /// Update model info response to be successful this time.
      fakeResponse = HTTPURLResponse(url: self.fakeFileURL,
                                     statusCode: 200,
                                     httpVersion: nil,
                                     headerFields: nil)!
    }

    let completionExpectation = expectation(description: "completion handler")

    let modelDownloadTask = ModelDownloadTask(remoteModelInfo: remoteModelInfo,
                                              appName: "fakeAppName",
                                              defaults: .createTestInstance(testName: #function),
                                              downloader: downloader,
                                              modelInfoRetriever: modelInfoRetriever) { result in
      completionExpectation.fulfill()
      switch result {
      case let .success(model):
        XCTAssertEqual(model.name, self.fakeModelName)
        XCTAssertEqual(model.size, self.fakeModelSize)
        XCTAssertEqual(model.hash, self.fakeModelHash)
        XCTAssertTrue(ModelFileManager.isFileReachable(at: URL(string: model.path)!))
      case let .failure(error):
        XCTFail("Error - \(error)")
      }
    }
    modelDownloadTask.download()

    // Wait for downloader to be called.
    wait(for: [fileDownloaderExpectation], timeout: 0.1)

    // Call download completion and wait for task completion.
    downloader
      .completion?(.success(FileDownloaderResponse(urlResponse: fakeResponse,
                                                   fileURL: tempFileURL)))

    wait(for: [completionExpectation], timeout: 0.5)

    // Cleanup temp file.
    try? ModelFileManager.removeFile(at: tempFileURL)
  }

  // TODO: Add this test after refactoring maybeRetryDownload().
  func testModelDownloadWithFailedRetry() {}
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
}

// MARK: - Helpers

extension NetworkingUnitTests {
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
      modelName: "fakeModelName",
      projectID: "fakeProjectID",
      apiKey: "fakeAPIKey",
      authTokenProvider: successAuthTokenProvider,
      appName: "fakeAppName",
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

  func fakeLocalModelInfo() -> LocalModelInfo {
    return LocalModelInfo(
      name: "fakeModelName",
      modelHash: "fakeModelHash",
      size: 20,
      path: "fakeModelPath"
    )
  }

  func fakeModelInfo() -> RemoteModelInfo {
    return RemoteModelInfo(name: fakeModelName,
                           downloadURL: fakeDownloadURL,
                           modelHash: fakeModelHash,
                           size: fakeModelSize,
                           urlExpiryTime: Date())
  }
}
