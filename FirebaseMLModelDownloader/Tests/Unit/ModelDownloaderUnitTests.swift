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

  /// Test to download model file.
  // TODO: Add unit test with mocks.
  func testStartModelDownload() {}

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
  var fakeSession = MockModelInfoRetrieverSession()
  let fakeModelName = "fakeModelName"
  let fakeModelHash = "fakeModelHash"
  let fakeDownloadURL = "www.fake-download-url.com"
  let fakeExpiryTime = "2021-01-20T04:20:10.220Z"
  let fakeModelSize = 20
  let fakeProjectID = "fakeProjectID"
  let fakeAPIKey = "fakeAPIKey"
  var fakeRemoteModelInfo: String {
    """
    {
      "downloadUri":"\(fakeDownloadURL)",
      "expireTime":"\(fakeExpiryTime)",
      "sizeBytes":"\(fakeModelSize)"
    }
    """
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
    fakeSession.data = fakeRemoteModelInfo.data(using: .utf8)
    fakeSession.response = HTTPURLResponse(
      url: URL(string: "www.fake-download-url.com")!,
      statusCode: 200,
      httpVersion: nil,
      headerFields: ["Etag": "fakeModelHash"]
    )
    fakeSession.error = nil

    let modelInfoRetriever = ModelInfoRetriever(
      modelName: "fakeModelName",
      projectID: "fakeProjectID",
      apiKey: "fakeAPIKey",
      installations: Installations.installations(),
      appName: "fakeAppName",
      session: fakeSession
    )

    modelInfoRetriever
      .authToken = { (completion: @escaping (Result<String, DownloadError>) -> Void) in
        completion(.success("fakeFISToken"))
      }

    modelInfoRetriever.downloadModelInfo { result in
      switch result {
      case let .success(fakemodelInfoResult):
        switch fakemodelInfoResult {
        case let .modelInfo(remoteModelInfo):
          XCTAssertEqual(remoteModelInfo.name, self.fakeModelName)
          XCTAssertEqual(remoteModelInfo.downloadURL.absoluteString, self.fakeDownloadURL)
          XCTAssertEqual(remoteModelInfo.size, self.fakeModelSize)
          XCTAssertEqual(remoteModelInfo.modelHash, self.fakeModelHash)
        case .notModified: XCTFail("Expected new model info from server.")
        }
      case let .failure(error): XCTFail("Failed with error - \(error)")
      }
    }
  }

  /// Get model info if model info is not modified.
  func testGetModelInfoWith304() {
    fakeSession.data = fakeRemoteModelInfo.data(using: .utf8)
    fakeSession.response = HTTPURLResponse(
      url: URL(string: "www.fake-download-url.com")!,
      statusCode: 304,
      httpVersion: nil,
      headerFields: ["Etag": "fakeModelHash"]
    )
    fakeSession.error = nil

    let fakeLocalModelInfo = LocalModelInfo(
      name: "fakeModelName",
      modelHash: "fakeModelHash",
      size: 20,
      path: "fakeModelPath"
    )

    let modelInfoRetriever = ModelInfoRetriever(
      modelName: "fakeModelName",
      projectID: "fakeProjectID",
      apiKey: "fakeAPIKey",
      installations: Installations.installations(),
      appName: "fakeAppName",
      localModelInfo: fakeLocalModelInfo,
      session: fakeSession
    )

    modelInfoRetriever
      .authToken = { (completion: @escaping (Result<String, DownloadError>) -> Void) in
        completion(.success("fakeFISToken"))
      }

    modelInfoRetriever.downloadModelInfo { result in
      switch result {
      case let .success(fakemodelInfoResult):
        switch fakemodelInfoResult {
        case .modelInfo: XCTFail("Unexpected new model info from server.")
        case .notModified: break
        }
      case let .failure(error): XCTFail("Failed with error - \(error)")
      }
    }
  }

  /// Get model info if model info is not modified but local model info is not set.
  func testGetModelInfoWith304Invalid() {
    fakeSession.data = fakeRemoteModelInfo.data(using: .utf8)
    fakeSession.response = HTTPURLResponse(
      url: URL(string: "www.fake-download-url.com")!,
      statusCode: 304,
      httpVersion: nil,
      headerFields: ["Etag": "fakeModelHash"]
    )
    fakeSession.error = nil

    let modelInfoRetriever = ModelInfoRetriever(
      modelName: "fakeModelName",
      projectID: "fakeProjectID",
      apiKey: "fakeAPIKey",
      installations: Installations.installations(),
      appName: "fakeAppName",
      session: fakeSession
    )

    modelInfoRetriever
      .authToken = { (completion: @escaping (Result<String, DownloadError>) -> Void) in
        completion(.success("fakeFISToken"))
      }

    modelInfoRetriever.downloadModelInfo { result in
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
  }

  /// Get model file if server returns a new model file.
  func testGetModelWith200() {
    fakeSession.data = fakeRemoteModelInfo.data(using: .utf8)
    fakeSession.response = HTTPURLResponse(
      url: URL(string: "www.fake-download-url.com")!,
      statusCode: 200,
      httpVersion: nil,
      headerFields: ["Etag": "fakeModelHash"]
    )
    fakeSession.error = nil

    let modelInfoRetriever = ModelInfoRetriever(
      modelName: "fakeModelName",
      projectID: "fakeProjectID",
      apiKey: "fakeAPIKey",
      installations: Installations.installations(),
      appName: "fakeAppName",
      session: fakeSession
    )

    let fakeRemoteModelInfo = RemoteModelInfo(name: fakeModelName,
                                              downloadURL: URL(string: fakeDownloadURL)!,
                                              modelHash: fakeModelHash,
                                              size: fakeModelSize,
                                              urlExpiryTime: Date())

    modelInfoRetriever
      .authToken = { (completion: @escaping (Result<String, DownloadError>) -> Void) in
        completion(.success("fakeFISToken"))
      }

    let conditions = ModelDownloadConditions()
    let modelDownloadTask = ModelDownloadTask(remoteModelInfo: fakeRemoteModelInfo,
                                              conditions: conditions,
                                              appName: "fakeAppName",
                                              defaults: .createTestInstance(testName: #function),
                                              modelInfoRetriever: modelInfoRetriever) { result in
      switch result {
      case let .success(model):
        XCTAssertEqual(model.name, self.fakeModelName)
        XCTAssertEqual(model.size, self.fakeModelSize)
        XCTAssertEqual(model.hash, self.fakeModelHash)
        XCTAssertTrue(ModelFileManager.isFileReachable(at: URL(string: model.path)!))
      case let .failure(error): XCTFail("Error - \(error)")
      }
    }

    let fakeResponse = HTTPURLResponse(url: URL(string: "www.fake-model-file.com")!,
                                       statusCode: 200,
                                       httpVersion: nil,
                                       headerFields: nil)!

    let tempDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory(),
                               isDirectory: true)
    let tempFileURL = tempDirectoryURL.appendingPathComponent("fake-model-file.tmp")
    let tempData: Data = "fakeModelData".data(using: .utf8)!
    try? tempData.write(to: tempFileURL)
    modelDownloadTask.handleResponse(response: fakeResponse,
                                     tempURL: tempFileURL)
    try? FileManager.default.removeItem(at: tempFileURL)
  }

  /// Get model file if download url expired.
  func testGetModelWith400() {
    fakeSession.data = fakeRemoteModelInfo.data(using: .utf8)
    fakeSession.response = HTTPURLResponse(
      url: URL(string: "www.fake-download-url.com")!,
      statusCode: 200,
      httpVersion: nil,
      headerFields: ["Etag": "fakeModelHash"]
    )
    fakeSession.error = nil

    let modelInfoRetriever = ModelInfoRetriever(
      modelName: "fakeModelName",
      projectID: "fakeProjectID",
      apiKey: "fakeAPIKey",
      installations: Installations.installations(),
      appName: "fakeAppName",
      session: fakeSession
    )

    let fakeRemoteModelInfo = RemoteModelInfo(name: fakeModelName,
                                              downloadURL: URL(string: fakeDownloadURL)!,
                                              modelHash: fakeModelHash,
                                              size: fakeModelSize,
                                              urlExpiryTime: Date())

    modelInfoRetriever
      .authToken = { (completion: @escaping (Result<String, DownloadError>) -> Void) in
        completion(.success("fakeFISToken"))
      }

    let conditions = ModelDownloadConditions()
    let modelDownloadTask = ModelDownloadTask(remoteModelInfo: fakeRemoteModelInfo,
                                              conditions: conditions,
                                              appName: "fakeAppName",
                                              defaults: .createTestInstance(testName: #function),
                                              modelInfoRetriever: modelInfoRetriever) { result in
      switch result {
      case .success:
        XCTFail("Should have failed due to expired URL.")
      case let .failure(error):
        switch error {
        case let .internalError(description: errorMessage): XCTAssertTrue(errorMessage
            .contains("Unable to resolve hostname"))
        default: XCTFail("Expected failure since local model info was not set.")
        }
      }
    }

    let fakeResponse = HTTPURLResponse(url: URL(string: "www.fake-model-file.com")!,
                                       statusCode: 400,
                                       httpVersion: nil,
                                       headerFields: nil)!

    let tempFileURL = URL(string: "file://fake/model/file")!
    modelDownloadTask.handleResponse(response: fakeResponse,
                                     tempURL: tempFileURL)
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
