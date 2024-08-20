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

import FirebaseAuth
import FirebaseCore
@testable import FirebaseStorage
import XCTest

/**
 * Firebase Storage Integration tests
 *
 * To run these tests, you need to define the following access rights:
 *
  rules_version = '2';
  service firebase.storage {
    match /b/{bucket}/o {
      match /{directChild=*} {
        allow read: if request.auth != null;
      }
      match /ios {
        match /public/{allPaths=**} {
          allow write: if request.auth != null;
          allow read: if true;
        }
        match /private/{allPaths=**} {
          allow read, write: if false;
        }
      }
    }
  }
 */

class StorageResultTests: StorageIntegrationCommon {
  func testGetMetadata() {
    let expectation = self.expectation(description: "testGetMetadata")
    let ref = storage.reference().child("ios/public/1mb")
    ref.getMetadata { result in
      self.assertResultSuccess(result)
      expectation.fulfill()
    }
    waitForExpectations()
  }

  func testUpdateMetadata() {
    let expectation = self.expectation(description: #function)

    let meta = StorageMetadata()
    meta.contentType = "lol/custom"
    meta.customMetadata = ["lol": "custom metadata is neat",
                           "ちかてつ": "🚇",
                           "shinkansen": "新幹線"]

    let ref = storage.reference(withPath: "ios/public/1mb")
    ref.updateMetadata(meta) { result in
      switch result {
      case let .success(metadata):
        XCTAssertEqual(meta.contentType, metadata.contentType)
        XCTAssertEqual(meta.customMetadata!["lol"], metadata.customMetadata!["lol"])
        XCTAssertEqual(meta.customMetadata!["ちかてつ"], metadata.customMetadata!["ちかてつ"])
        XCTAssertEqual(meta.customMetadata!["shinkansen"],
                       metadata.customMetadata!["shinkansen"])
      case let .failure(error):
        XCTFail("Unexpected error \(error) from updateMetadata")
      }
      expectation.fulfill()
    }
    waitForExpectations()
  }

  func testDelete() throws {
    let expectation = self.expectation(description: #function)
    let ref = storage.reference(withPath: "ios/public/fileToDelete")
    let data = try XCTUnwrap("Hello Swift World".data(using: .utf8), "Data construction failed")
    ref.putData(data) { result in
      self.assertResultSuccess(result)
      ref.delete { error in
        XCTAssertNil(error, "Error should be nil")
        // Next delete should fail and verify the first delete succeeded.
        ref.delete { error in
          do {
            let nsError = try XCTUnwrap(error as? NSError)
            XCTAssertEqual(nsError.code, StorageErrorCode.objectNotFound.rawValue)
            XCTAssertEqual(
              nsError.localizedDescription,
              "Object ios/public/fileToDelete does not exist."
            )
            let userInfo = try XCTUnwrap(nsError.userInfo)
            let object = try XCTUnwrap(userInfo["object"] as? String)
            XCTAssertEqual(object, "ios/public/fileToDelete")
            let responseErrorCode = try XCTUnwrap(userInfo["ResponseErrorCode"] as? Int)
            XCTAssertEqual(responseErrorCode, 404)
            let responseErrorDomain = try XCTUnwrap(userInfo["ResponseErrorDomain"] as? String)
            XCTAssertEqual(responseErrorDomain, "com.google.HTTPStatus")
            let bucket = try XCTUnwrap(userInfo["bucket"] as? String)
            XCTAssertEqual(bucket, "ios-opensource-samples.appspot.com")
            expectation.fulfill()
          } catch {
            XCTFail("Unexpected unwrap failure")
          }
        }
      }
    }
    waitForExpectations()
  }

  func testDeleteWithNilCompletion() throws {
    let expectation = self.expectation(description: #function)
    let ref = storage.reference(withPath: "ios/public/fileToDelete")
    let data = try XCTUnwrap("Hello Swift World".data(using: .utf8), "Data construction failed")
    ref.putData(data) { result in
      self.assertResultSuccess(result)
      ref.delete(completion: nil)
      expectation.fulfill()
    }
    waitForExpectations()
  }

  func testSimplePutData() throws {
    let expectation = self.expectation(description: #function)
    let ref = storage.reference(withPath: "ios/public/testBytesUpload")
    let data = try XCTUnwrap("Hello Swift World".data(using: .utf8), "Data construction failed")
    ref.putData(data) { result in
      self.assertResultSuccess(result)
      expectation.fulfill()
    }
    waitForExpectations()
  }

  func testNoDeadlocks() throws {
    let storage2 = Storage.storage(url: "")

    let expectation1 = expectation(description: #function)
    let expectation2 = expectation(description: #function)
    let ref = storage.reference(withPath: "ios/public/testBytesUpload")
    let data = try XCTUnwrap("Hello Swift World".data(using: .utf8), "Data construction failed")
    ref.putData(data) { result in
      expectation1.fulfill()

      let ref2 = storage2.reference(withPath: "ios/public/testBytesUpload")
      ref2.putData(data) { result in
        expectation2.fulfill()
      }
    }
    waitForExpectations(timeout: 30)
  }

  func testSimplePutSpecialCharacter() throws {
    let expectation = self.expectation(description: #function)
    let ref = storage.reference(withPath: "ios/public/-._~!$'()*,=:@&+;")
    let data = try XCTUnwrap("Hello Swift World".data(using: .utf8), "Data construction failed")
    ref.putData(data) { result in
      self.assertResultSuccess(result)
      expectation.fulfill()
    }
    waitForExpectations()
  }

  func testSimplePutDataInBackgroundQueue() throws {
    let expectation = self.expectation(description: #function)
    let ref = storage.reference(withPath: "ios/public/testBytesUpload")
    let data = try XCTUnwrap("Hello Swift World".data(using: .utf8), "Data construction failed")
    DispatchQueue.global(qos: .background).async {
      ref.putData(data) { result in
        self.assertResultSuccess(result)
        expectation.fulfill()
      }
    }
    waitForExpectations()
  }

  func testSimplePutEmptyData() {
    let expectation = self.expectation(description: #function)
    let ref = storage.reference(withPath: "ios/public/testSimplePutEmptyData")
    let data = Data()
    ref.putData(data) { result in
      self.assertResultSuccess(result)
      expectation.fulfill()
    }
    waitForExpectations()
  }

  func testSimplePutDataUnauthorized() throws {
    let expectation = self.expectation(description: #function)
    let file = "ios/private/secretfile.txt"
    let ref = storage.reference(withPath: file)
    let data = try XCTUnwrap("Hello Swift World".data(using: .utf8), "Data construction failed")
    ref.putData(data) { result in
      switch result {
      case .success:
        XCTFail("Unexpected success from unauthorized putData")
      case let .failure(error as StorageError):
        switch error {
        case let .unauthorized(bucket, object, serverError):
          XCTAssertEqual(bucket, "ios-opensource-samples.appspot.com")
          XCTAssertEqual(object, file)
          XCTAssertNotNil(serverError)
          XCTAssertEqual(serverError["ResponseErrorCode"] as? Int, 403)
          expectation.fulfill()
        default:
          XCTFail("Failed with unexpected error: \(error)")
        }
      case let .failure(error):
        XCTFail("Failed with unexpected error: \(error)")
      }
    }
    waitForExpectations()
  }

  func testSimplePutDataUnauthorizedThrow() throws {
    let expectation = self.expectation(description: #function)
    let ref = storage.reference(withPath: "ios/private/secretfile.txt")
    let data = try XCTUnwrap("Hello Swift World".data(using: .utf8), "Data construction failed")
    ref.putData(data) { result in
      do {
        try _ = result.get() // .failure will throw
      } catch {
        expectation.fulfill()
        return
      }
      XCTFail("Unexpected success from unauthorized putData")
      expectation.fulfill()
    }
    waitForExpectations()
  }

  func testSimplePutFile() throws {
    let expectation = self.expectation(description: #function)
    let putFileExpectation = self.expectation(description: "putFile")
    let ref = storage.reference(withPath: "ios/public/testSimplePutFile")
    let data = try XCTUnwrap("Hello Swift World".data(using: .utf8), "Data construction failed")
    let tmpDirURL = URL(fileURLWithPath: NSTemporaryDirectory())
    let fileURL = tmpDirURL.appendingPathComponent("hello.txt")
    try data.write(to: fileURL, options: .atomicWrite)
    let task = ref.putFile(from: fileURL) { result in
      self.assertResultSuccess(result)
      putFileExpectation.fulfill()
    }

    task.observe(StorageTaskStatus.success) { snapshot in
      XCTAssertEqual(snapshot.description, "<State: Success>")
      expectation.fulfill()
    }

    var uploadedBytes: Int64 = -1

    task.observe(StorageTaskStatus.progress) { snapshot in
      XCTAssertTrue(snapshot.description.starts(with: "<State: Progress") ||
        snapshot.description.starts(with: "<State: Resume"))
      guard let progress = snapshot.progress else {
        XCTFail("Failed to get snapshot.progress")
        return
      }
      XCTAssertGreaterThanOrEqual(progress.completedUnitCount, uploadedBytes)
      uploadedBytes = progress.completedUnitCount
    }
    waitForExpectations()
  }

  func testPutFileLimitedChunk() throws {
    defer {
      // Reset since tests share storage instance.
      storage.uploadChunkSizeBytes = Int64.max
    }
    let expectation = self.expectation(description: #function)
    let putFileExpectation = self.expectation(description: "putFile")
    let ref = storage.reference(withPath: "ios/public/testPutFilePauseResume")
    let bundle = Bundle(for: StorageIntegrationCommon.self)
    let filePath = try XCTUnwrap(bundle.path(forResource: "1mb", ofType: "dat"),
                                 "Failed to get filePath")
    let data = try XCTUnwrap(Data(contentsOf: URL(fileURLWithPath: filePath)),
                             "Failed to load file")
    let tmpDirURL = URL(fileURLWithPath: NSTemporaryDirectory())
    let fileURL = tmpDirURL.appendingPathComponent("LargePutFile.txt")
    var progressCount = 0

    try data.write(to: fileURL, options: .atomicWrite)

    // Limit the upload chunk size
    storage.uploadChunkSizeBytes = 256_000

    let task = ref.putFile(from: fileURL) { result in
      XCTAssertGreaterThanOrEqual(progressCount, 4)
      self.assertResultSuccess(result)
      putFileExpectation.fulfill()
    }

    task.observe(StorageTaskStatus.success) { snapshot in
      XCTAssertEqual(snapshot.description, "<State: Success>")
      expectation.fulfill()
    }

    var uploadedBytes: Int64 = -1

    task.observe(StorageTaskStatus.progress) { snapshot in
      XCTAssertTrue(snapshot.description.starts(with: "<State: Progress") ||
        snapshot.description.starts(with: "<State: Resume"))
      guard let progress = snapshot.progress else {
        XCTFail("Failed to get snapshot.progress")
        return
      }
      progressCount = progressCount + 1
      XCTAssertGreaterThanOrEqual(progress.completedUnitCount, uploadedBytes)
      uploadedBytes = progress.completedUnitCount
    }
    waitForExpectations()
  }

  func testPutFileTinyChunk() throws {
    defer {
      // Reset since tests share storage instance.
      storage.uploadChunkSizeBytes = Int64.max
    }
    let expectation = self.expectation(description: #function)
    let putFileExpectation = self.expectation(description: "putFile")
    let ref = storage.reference(withPath: "ios/public/testPutFilePauseResume")
    let bundle = Bundle(for: StorageIntegrationCommon.self)
    let filePath = try XCTUnwrap(bundle.path(forResource: "1mb", ofType: "dat"),
                                 "Failed to get filePath")
    let data = try XCTUnwrap(Data(contentsOf: URL(fileURLWithPath: filePath)),
                             "Failed to load file")
    let tmpDirURL = URL(fileURLWithPath: NSTemporaryDirectory())
    let fileURL = tmpDirURL.appendingPathComponent("LargePutFile.txt")
    var progressCount = 0

    try data.write(to: fileURL, options: .atomicWrite)

    // Limit the upload chunk size. This should behave exactly like the previous
    // test since small chunk sizes are rounded up to 256K.
    storage.uploadChunkSizeBytes = 1

    let task = ref.putFile(from: fileURL) { result in
      XCTAssertGreaterThanOrEqual(progressCount, 4)
      XCTAssertLessThanOrEqual(progressCount, 6)
      self.assertResultSuccess(result)
      putFileExpectation.fulfill()
    }

    task.observe(StorageTaskStatus.success) { snapshot in
      XCTAssertEqual(snapshot.description, "<State: Success>")
      expectation.fulfill()
    }

    var uploadedBytes: Int64 = -1

    task.observe(StorageTaskStatus.progress) { snapshot in
      XCTAssertTrue(snapshot.description.starts(with: "<State: Progress") ||
        snapshot.description.starts(with: "<State: Resume"))
      guard let progress = snapshot.progress else {
        XCTFail("Failed to get snapshot.progress")
        return
      }
      progressCount = progressCount + 1
      XCTAssertGreaterThanOrEqual(progress.completedUnitCount, uploadedBytes)
      uploadedBytes = progress.completedUnitCount
    }
    waitForExpectations()
  }

  func testAttemptToUploadDirectoryShouldFail() throws {
    // This `.numbers` file is actually a directory.
    let fileName = "HomeImprovement.numbers"
    let expectation = self.expectation(description: #function)
    let bundle = Bundle(for: StorageIntegrationCommon.self)
    let fileURL = try XCTUnwrap(bundle.url(forResource: fileName, withExtension: ""),
                                "Failed to get filePath")
    let ref = storage.reference(withPath: "ios/public/" + fileName)
    ref.putFile(from: fileURL) { result in
      self.assertResultFailure(result)
      expectation.fulfill()
    }
    waitForExpectations()
  }

  func testPutFileWithSpecialCharacters() throws {
    let expectation = self.expectation(description: #function)

    let fileName = "hello&+@_ .txt"
    let ref = storage.reference(withPath: "ios/public/" + fileName)
    let data = try XCTUnwrap("Hello Swift World".data(using: .utf8), "Data construction failed")
    let tmpDirURL = URL(fileURLWithPath: NSTemporaryDirectory())
    let fileURL = tmpDirURL.appendingPathComponent("hello.txt")
    try data.write(to: fileURL, options: .atomicWrite)
    ref.putFile(from: fileURL) { result in
      switch result {
      case let .success(metadata):
        XCTAssertEqual(fileName, metadata.name)
        ref.getMetadata { result in
          self.assertResultSuccess(result)
        }
      case let .failure(error):
        XCTFail("Unexpected error \(error) from putFile")
      }
      expectation.fulfill()
    }
    waitForExpectations()
  }

  func testSimplePutDataNoMetadata() throws {
    let expectation = self.expectation(description: #function)

    let ref = storage.reference(withPath: "ios/public/testSimplePutDataNoMetadata")
    let data = try XCTUnwrap("Hello Swift World".data(using: .utf8), "Data construction failed")

    ref.putData(data) { result in
      self.assertResultSuccess(result)
      expectation.fulfill()
    }
    waitForExpectations()
  }

  func testSimplePutFileNoMetadata() throws {
    let expectation = self.expectation(description: #function)

    let fileName = "hello&+@_ .txt"
    let ref = storage.reference(withPath: "ios/public/" + fileName)
    let data = try XCTUnwrap("Hello Swift World".data(using: .utf8), "Data construction failed")
    let tmpDirURL = URL(fileURLWithPath: NSTemporaryDirectory())
    let fileURL = tmpDirURL.appendingPathComponent("hello.txt")
    try data.write(to: fileURL, options: .atomicWrite)
    ref.putFile(from: fileURL) { result in
      self.assertResultSuccess(result)
      expectation.fulfill()
    }
    waitForExpectations()
  }

  func testSimpleGetData() {
    let expectation = self.expectation(description: #function)

    let ref = storage.reference(withPath: "ios/public/1mb")
    ref.getData(maxSize: 1024 * 1024) { result in
      self.assertResultSuccess(result)
      expectation.fulfill()
    }
    waitForExpectations()
  }

  func testSimpleGetDataInBackgroundQueue() {
    let expectation = self.expectation(description: #function)

    let ref = storage.reference(withPath: "ios/public/1mb")
    DispatchQueue.global(qos: .background).async {
      ref.getData(maxSize: 1024 * 1024) { result in
        self.assertResultSuccess(result)
        expectation.fulfill()
      }
    }
    waitForExpectations()
  }

  func testSimpleGetDataWithCustomCallbackQueue() {
    let expectation = self.expectation(description: #function)

    let callbackQueueLabel = "customCallbackQueue"
    let callbackQueueKey = DispatchSpecificKey<String>()
    let callbackQueue = DispatchQueue(label: callbackQueueLabel)
    callbackQueue.setSpecific(key: callbackQueueKey, value: callbackQueueLabel)
    storage.callbackQueue = callbackQueue

    let ref = storage.reference(withPath: "ios/public/1mb")
    ref.getData(maxSize: 1024 * 1024) { result in
      self.assertResultSuccess(result)

      XCTAssertFalse(Thread.isMainThread)

      let currentQueueLabel = DispatchQueue.getSpecific(key: callbackQueueKey)
      XCTAssertEqual(currentQueueLabel, callbackQueueLabel)

      expectation.fulfill()

      // Reset the callbackQueue to default (main queue).
      self.storage.callbackQueue = DispatchQueue.main
      callbackQueue.setSpecific(key: callbackQueueKey, value: nil)
    }
    waitForExpectations()
  }

  func testSimpleGetDataTooSmall() {
    let expectation = self.expectation(description: #function)

    let ref = storage.reference(withPath: "ios/public/1mb")
    let maxSize: Int64 = 1024
    ref.getData(maxSize: maxSize) { result in
      switch result {
      case .success:
        XCTFail("Unexpected success from getData too small")
      case let .failure(error as StorageError):
        switch error {
        case let .downloadSizeExceeded(total, max):
          XCTAssertEqual(total, 1_048_576)
          XCTAssertEqual(max, maxSize)
        default:
          XCTFail("Failed with unexpected error: \(error)")
        }
      case let .failure(error):
        XCTFail("Failed with unexpected error: \(error)")
      }
      expectation.fulfill()
    }
    waitForExpectations()
  }

  func testSimpleGetDownloadURL() {
    let expectation = self.expectation(description: #function)

    let ref = storage.reference(withPath: "ios/public/1mb")

    // Download URL format is
    // "https://firebasestorage.googleapis.com:443/v0/b/{bucket}/o/{path}?alt=media&token={token}"
    let downloadURLPrefix =
      "https://firebasestorage.googleapis.com:443/v0/b/ios-opensource-samples" +
      ".appspot.com/o/ios%2Fpublic%2F1mb?alt=media&token"

    ref.downloadURL { result in
      switch result {
      case let .success(downloadURL):
        let urlString = downloadURL.absoluteString
        XCTAssertTrue(urlString.hasPrefix(downloadURLPrefix))
      case let .failure(error):
        XCTFail("Unexpected error \(error) from downloadURL")
      }
      expectation.fulfill()
    }
    waitForExpectations()
  }

  func testSimpleGetFile() throws {
    let expectation = self.expectation(description: #function)
    let ref = storage.reference(withPath: "ios/public/helloworld" + #function)
    let tmpDirURL = URL(fileURLWithPath: NSTemporaryDirectory())
    let fileURL = tmpDirURL.appendingPathComponent(#function + "hello.txt")
    let data = try XCTUnwrap("Hello Swift World".data(using: .utf8), "Data construction failed")

    ref.putData(data) { result in
      switch result {
      case .success:
        let task = ref.write(toFile: fileURL)

        task.observe(StorageTaskStatus.success) { snapshot in
          do {
            let stringData = try String(contentsOf: fileURL, encoding: .utf8)
            XCTAssertEqual(stringData, "Hello Swift World")
            XCTAssertEqual(snapshot.description, "<State: Success>")
          } catch {
            XCTFail("Error processing success snapshot")
          }
          expectation.fulfill()
        }

        task.observe(StorageTaskStatus.progress) { snapshot in
          XCTAssertNil(snapshot.error, "Error should be nil")
          guard let progress = snapshot.progress else {
            XCTFail("Missing progress")
            return
          }
          print("\(progress.completedUnitCount) of \(progress.totalUnitCount)")
        }
        task.observe(StorageTaskStatus.failure) { snapshot in
          XCTAssertNil(snapshot.error, "Error should be nil")
        }
      case let .failure(error):
        XCTFail("Unexpected error \(error) from putData")
        expectation.fulfill()
      }
    }
    waitForExpectations()
  }

  func testCancelErrorCode() throws {
    let expectation = self.expectation(description: #function)
    let ref = storage.reference(withPath: "ios/public/helloworld" + #function)
    let tmpDirURL = URL(fileURLWithPath: NSTemporaryDirectory())
    let fileURL = tmpDirURL.appendingPathComponent(#function + "hello.txt")
    let data = try XCTUnwrap("Hello Swift World".data(using: .utf8), "Data construction failed")

    ref.putData(data) { result in
      switch result {
      case .success:
        let task = ref.write(toFile: fileURL)

        task.observe(StorageTaskStatus.success) { snapshot in
          XCTFail("Error processing success snapshot")
          expectation.fulfill()
        }

        task.observe(StorageTaskStatus.failure) { snapshot in
          let expected = "User cancelled the upload/download."
          if let error = snapshot.error {
            let errorDescription = error.localizedDescription
            XCTAssertEqual(errorDescription, expected)
            let code = (error as NSError).code
            XCTAssertEqual(code, StorageErrorCode.cancelled.rawValue)
          }
          expectation.fulfill()
        }
        task.cancel()
      case let .failure(error):
        XCTFail("Unexpected error \(error) from putData")
        expectation.fulfill()
      }
    }
    waitForExpectations()
  }

  private func assertMetadata(actualMetadata: StorageMetadata,
                              expectedContentType: String,
                              expectedCustomMetadata: [String: String]) {
    XCTAssertEqual(actualMetadata.cacheControl, "cache-control")
    XCTAssertEqual(actualMetadata.contentDisposition, "content-disposition")
    XCTAssertEqual(actualMetadata.contentEncoding, "gzip")
    XCTAssertEqual(actualMetadata.contentLanguage, "de")
    XCTAssertEqual(actualMetadata.contentType, expectedContentType)
    XCTAssertEqual(actualMetadata.md5Hash?.count, 24)
    for (key, value) in expectedCustomMetadata {
      XCTAssertEqual(actualMetadata.customMetadata![key], value)
    }
  }

  private func assertMetadataNil(actualMetadata: StorageMetadata) {
    XCTAssertNil(actualMetadata.cacheControl)
    XCTAssertNil(actualMetadata.contentDisposition)
    XCTAssertEqual(actualMetadata.contentEncoding, "identity")
    XCTAssertNil(actualMetadata.contentLanguage)
    XCTAssertNil(actualMetadata.contentType)
    XCTAssertEqual(actualMetadata.md5Hash?.count, 24)
    XCTAssertNil(actualMetadata.customMetadata)
  }

  func testUpdateMetadata2() {
    let expectation = self.expectation(description: #function)
    let ref = storage.reference(withPath: "ios/public/1mb")

    let metadata = StorageMetadata()
    metadata.cacheControl = "cache-control"
    metadata.contentDisposition = "content-disposition"
    metadata.contentEncoding = "gzip"
    metadata.contentLanguage = "de"
    metadata.contentType = "content-type-a"
    metadata.customMetadata = ["a": "b"]

    ref.updateMetadata(metadata) { updatedMetadata, error in
      XCTAssertNil(error, "Error should be nil")
      guard let updatedMetadata = updatedMetadata else {
        XCTFail("Metadata is nil")
        expectation.fulfill()
        return
      }
      self.assertMetadata(actualMetadata: updatedMetadata,
                          expectedContentType: "content-type-a",
                          expectedCustomMetadata: ["a": "b"])

      let metadata = updatedMetadata
      metadata.contentType = "content-type-b"
      metadata.customMetadata = ["a": "b", "c": "d"]

      ref.updateMetadata(metadata) { result in
        switch result {
        case let .success(updatedMetadata):
          self.assertMetadata(actualMetadata: updatedMetadata,
                              expectedContentType: "content-type-b",
                              expectedCustomMetadata: ["a": "b", "c": "d"])
          metadata.cacheControl = nil
          metadata.contentDisposition = nil
          metadata.contentEncoding = nil
          metadata.contentLanguage = nil
          metadata.contentType = nil
          metadata.customMetadata = nil
          ref.updateMetadata(metadata) { result in
            self.assertResultSuccess(result)
            expectation.fulfill()
          }
        case let .failure(error):
          XCTFail("Unexpected error \(error) from updateMetadata")
          expectation.fulfill()
        }
      }
    }
    waitForExpectations()
  }

  func testResumeGetFile() {
    let expectation = self.expectation(description: #function)
    let expectationPause = self.expectation(description: "pause")
    let expectationResume = self.expectation(description: "resume")
    let ref = storage.reference().child("ios/public/1mb")

    let fileURL = URL(fileURLWithPath: "\(NSTemporaryDirectory())/hello.txt")
    let task = ref.write(toFile: fileURL)
    var downloadedBytes: Int64 = 0
    var resumeAtBytes = 256 * 1024

    task.observe(StorageTaskStatus.success) { snapshot in
      XCTAssertEqual(snapshot.description, "<State: Success>")
      expectation.fulfill()
    }
    task.observe(StorageTaskStatus.progress) { snapshot in
      let description = snapshot.description
      XCTAssertTrue(description.contains("State: Progress") ||
        description.contains("State: Resume"))
      let progress = snapshot.progress
      if let completed = progress?.completedUnitCount {
        XCTAssertGreaterThanOrEqual(completed, downloadedBytes)
        downloadedBytes = completed
        if completed > resumeAtBytes {
          task.pause()
          expectationPause.fulfill()
          resumeAtBytes = Int.max
        }
      }
    }
    task.observe(StorageTaskStatus.pause) { snapshot in
      XCTAssertEqual(snapshot.description, "<State: Paused>")
      task.resume()
      expectationResume.fulfill()
    }
    waitForExpectations()
    XCTAssertEqual(resumeAtBytes, Int.max)
  }

  func testResumeGetFileInBackgroundQueue() {
    let expectation = self.expectation(description: #function)
    let expectationPause = self.expectation(description: "pause")
    let expectationResume = self.expectation(description: "resume")
    let ref = storage.reference().child("ios/public/1mb")

    let fileURL = URL(fileURLWithPath: "\(NSTemporaryDirectory())/hello.txt")
    let task = ref.write(toFile: fileURL)
    var downloadedBytes: Int64 = 0
    var resumeAtBytes = 256 * 1024

    task.observe(StorageTaskStatus.success) { snapshot in
      XCTAssertEqual(snapshot.description, "<State: Success>")
      expectation.fulfill()
    }
    task.observe(StorageTaskStatus.progress) { snapshot in
      let description = snapshot.description
      XCTAssertTrue(description.contains("State: Progress") ||
        description.contains("State: Resume"))
      let progress = snapshot.progress
      if let completed = progress?.completedUnitCount {
        XCTAssertGreaterThanOrEqual(completed, downloadedBytes)
        downloadedBytes = completed
        if completed > resumeAtBytes {
          DispatchQueue.global(qos: .background).async {
            task.pause()
          }
          expectationPause.fulfill()
          resumeAtBytes = Int.max
        }
      }
    }
    task.observe(StorageTaskStatus.pause) { snapshot in
      XCTAssertEqual(snapshot.description, "<State: Paused>")
      DispatchQueue.global(qos: .background).async {
        task.resume()
      }
      expectationResume.fulfill()
    }
    waitForExpectations()
    XCTAssertEqual(resumeAtBytes, Int.max)
  }

  func testPagedListFiles() {
    let expectation = self.expectation(description: #function)
    let ref = storage.reference(withPath: "ios/public/list")

    ref.list(maxResults: 2) { result in
      switch result {
      case let .success(listResult):
        XCTAssertEqual(listResult.items, [ref.child("a"), ref.child("b")])
        XCTAssertEqual(listResult.prefixes, [])
        guard let pageToken = listResult.pageToken else {
          XCTFail("pageToken should not be nil")
          expectation.fulfill()
          return
        }
        ref.list(maxResults: 2, pageToken: pageToken) { result in
          switch result {
          case let .success(listResult):
            XCTAssertEqual(listResult.items, [])
            XCTAssertEqual(listResult.prefixes, [ref.child("prefix")])
            XCTAssertNil(listResult.pageToken, "pageToken should be nil")
          case let .failure(error):
            XCTFail("Unexpected error \(error) from list")
          }
          expectation.fulfill()
        }
      case let .failure(error):
        XCTFail("Unexpected error \(error) from list")
        expectation.fulfill()
      }
    }
    waitForExpectations()
  }

  func testPagedListFilesTooManyError() {
    let expectation = self.expectation(description: #function)
    let ref = storage.reference(withPath: "ios/public/list")

    ref.list(maxResults: 22222) { result in
      switch result {
      case .success:
        XCTFail("Unexpected success from list")
      case let .failure(error as StorageError):
        switch error {
        case let .invalidArgument(message):
          XCTAssertEqual(message, "Argument 'maxResults' must be between 1 and 1000 inclusive.")
        default:
          XCTFail("Failed with unexpected error: \(error)")
        }
      case let .failure(error):
        XCTFail("Failed with unexpected error: \(error)")
      }
      expectation.fulfill()
    }
    waitForExpectations()
  }

  func testListAllFiles() {
    let expectation = self.expectation(description: #function)
    let ref = storage.reference(withPath: "ios/public/list")

    ref.listAll { result in
      switch result {
      case let .success(listResult):
        XCTAssertEqual(listResult.items, [ref.child("a"), ref.child("b")])
        XCTAssertEqual(listResult.prefixes, [ref.child("prefix")])
        XCTAssertNil(listResult.pageToken, "pageToken should be nil")
      case let .failure(error):
        XCTFail("Unexpected error \(error) from list")
      }
      expectation.fulfill()
    }
    waitForExpectations()
  }

  private func waitForExpectations() {
    let kFIRStorageIntegrationTestTimeout = 100.0
    waitForExpectations(timeout: kFIRStorageIntegrationTestTimeout,
                        handler: { error in
                          if let error {
                            print(error)
                          }
                        })
  }

  private func assertResultSuccess<T>(_ result: Result<T, Error>,
                                      file: StaticString = #file, line: UInt = #line) {
    switch result {
    case let .success(value):
      XCTAssertNotNil(value, file: file, line: line)
    case let .failure(error):
      XCTFail("Unexpected error \(error)")
    }
  }

  private func assertResultFailure<T>(_ result: Result<T, Error>,
                                      file: StaticString = #file, line: UInt = #line) {
    switch result {
    case let .success(value):
      XCTFail("Unexpected success with value: \(value)")
    case let .failure(error):
      XCTAssertNotNil(error, file: file, line: line)
    }
  }
}
