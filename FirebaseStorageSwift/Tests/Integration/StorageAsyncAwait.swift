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

import FirebaseAuth
import FirebaseCore
import FirebaseStorage
import FirebaseStorageSwift
import XCTest

@available(iOS 15.0, *)
class StorageAsyncAwait: StorageIntegrationCommon {
  func testGetMetadata() async throws {
    let ref = storage.reference().child("ios/public/1mb2")
    let result = try await ref.getMetadata()
    XCTAssertNotNil(result)
  }

  func testUpdateMetadata() async throws {
    let meta = StorageMetadata()
    meta.contentType = "lol/custom"
    meta.customMetadata = ["lol": "custom metadata is neat",
                           "ちかてつ": "🚇",
                           "shinkansen": "新幹線"]

    let ref = storage.reference(withPath: "ios/public/1mb2")
    let metadata = try await ref.updateMetadata(meta)
    XCTAssertEqual(meta.contentType, metadata.contentType)
    XCTAssertEqual(meta.customMetadata!["lol"], metadata.customMetadata!["lol"])
    XCTAssertEqual(meta.customMetadata!["ちかてつ"], metadata.customMetadata!["ちかてつ"])
    XCTAssertEqual(meta.customMetadata!["shinkansen"],
                   metadata.customMetadata!["shinkansen"])
  }

  func testDelete() async throws {
    let ref = storage.reference(withPath: "ios/public/fileToDelete")
    let data = try XCTUnwrap("Hello Swift World".data(using: .utf8), "Data construction failed")
    let result = try await ref.putDataAwait(data, metadata: nil)
    XCTAssertNotNil(result)
    let _ = try await ref.delete()
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
    let ref = storage.reference(withPath: "ios/private/secretfile.txt")
    let data = try XCTUnwrap("Hello Swift World".data(using: .utf8), "Data construction failed")
    ref.putData(data) { result in
      switch result {
      case .success:
        XCTFail("Unexpected success from unauthorized putData")
      case let .failure(error as NSError):
        XCTAssertEqual(error.code, StorageErrorCode.unauthorized.rawValue)
        expectation.fulfill()
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

  func testAttemptToUploadDirectoryShouldFail() throws {
    // This `.numbers` file is actually a directory.
    let fileName = "HomeImprovement.numbers"
    let bundle = Bundle(for: StorageIntegrationCommon.self)
    let fileURL = try XCTUnwrap(bundle.url(forResource: fileName, withExtension: ""),
                                "Failed to get filePath")
    let ref = storage.reference(withPath: "ios/public/" + fileName)
    ref.putFile(from: fileURL) { result in
      self.assertResultFailure(result)
    }
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

  func testSimplePutDataNoMetadata() async throws {
    let ref = storage.reference(withPath: "ios/public/testSimplePutDataNoMetadata")
    let data = try XCTUnwrap("Hello Swift World".data(using: .utf8), "Data construction failed")
    let result = try await ref.putDataAwait(data)
    XCTAssertNotNil(result)
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

  func testSimpleGetData() async throws {
    let ref = storage.reference(withPath: "ios/public/1mb2")
    let result = try await ref.data(maxSize: 1024 * 1024)
    XCTAssertNotNil(result)
  }

  func testSimpleGetDataInBackgroundQueue() async throws {
    actor MyBackground {
      func doit(_ ref: StorageReference) async throws -> Data {
        XCTAssertFalse(Thread.isMainThread)
        return try await ref.data(maxSize: 1024 * 1024)
      }
    }
    let ref = storage.reference(withPath: "ios/public/1mb2")
    let result = try await MyBackground().doit(ref)
    XCTAssertNotNil(result)
  }

  func testSimpleGetDataTooSmall() async {
    let ref = storage.reference(withPath: "ios/public/1mb2")
    do {
      _ = try await ref.data(maxSize: 1024)
      XCTFail("Unexpected success from getData too small")
    } catch {
      XCTAssertEqual((error as NSError).code, StorageErrorCode.downloadSizeExceeded.rawValue)
    }
  }

  func testSimpleGetDownloadURL() async throws {
    let ref = storage.reference(withPath: "ios/public/1mb2")

    // Download URL format is
    // "https://firebasestorage.googleapis.com:443/v0/b/{bucket}/o/{path}?alt=media&token={token}"
    let downloadURLPattern =
      "^https:\\/\\/firebasestorage.googleapis.com:443\\/v0\\/b\\/[^\\/]*\\/o\\/" +
      "ios%2Fpublic%2F1mb2\\?alt=media&token=[a-z0-9-]*$"

    let downloadURL = try await ref.downloadURL()
    let testRegex = try NSRegularExpression(pattern: downloadURLPattern)
    let urlString = downloadURL.absoluteString
    XCTAssertEqual(testRegex.numberOfMatches(in: urlString,
                                             range: NSRange(location: 0,
                                                            length: urlString.count)), 1)
  }

  func testSimpleGetFile() throws {
    let expectation = self.expectation(description: #function)
    let ref = storage.reference(withPath: "ios/public/helloworld")
    let tmpDirURL = URL(fileURLWithPath: NSTemporaryDirectory())
    let fileURL = tmpDirURL.appendingPathComponent("hello.txt")
    let data = try XCTUnwrap("Hello Swift World".data(using: .utf8), "Data construction failed")

    async {
      try await ref.putDataAwait(data)
      let task = ref.write(toFile: fileURL)

      // TODO: Update to use Swift Tasks
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

  func testUpdateMetadata2() async throws {
    let ref = storage.reference(withPath: "ios/public/1mb2")

    let metadata = StorageMetadata()
    metadata.cacheControl = "cache-control"
    metadata.contentDisposition = "content-disposition"
    metadata.contentEncoding = "gzip"
    metadata.contentLanguage = "de"
    metadata.contentType = "content-type-a"
    metadata.customMetadata = ["a": "b"]

    let updatedMetadata = try await ref.updateMetadata(metadata)
    assertMetadata(actualMetadata: updatedMetadata,
                   expectedContentType: "content-type-a",
                   expectedCustomMetadata: ["a": "b"])

    let metadata2 = updatedMetadata
    metadata2.contentType = "content-type-b"
    metadata2.customMetadata = ["a": "b", "c": "d"]

    let metadata3 = try await ref.updateMetadata(metadata2)
    assertMetadata(actualMetadata: metadata3,
                   expectedContentType: "content-type-b",
                   expectedCustomMetadata: ["a": "b", "c": "d"])
    metadata.cacheControl = nil
    metadata.contentDisposition = nil
    metadata.contentEncoding = nil
    metadata.contentLanguage = nil
    metadata.contentType = nil
    metadata.customMetadata = nil
    let metadata4 = try await ref.updateMetadata(metadata)
    XCTAssertNotNil(metadata4)
  }

  func testPagedListFiles() async throws {
    let ref = storage.reference(withPath: "ios/public/list")
    let listResult = try await ref.list(maxResults: 2)
    XCTAssertEqual(listResult.items, [ref.child("a"), ref.child("b")])
    XCTAssertEqual(listResult.prefixes, [])
    guard let pageToken = listResult.pageToken else {
      XCTFail("pageToken should not be nil")
      return
    }
    let listResult2 = try await ref.list(maxResults: 2, pageToken: pageToken)
    XCTAssertEqual(listResult2.items, [])
    XCTAssertEqual(listResult2.prefixes, [ref.child("prefix")])
    XCTAssertNil(listResult2.pageToken, "pageToken should be nil")
  }

  func testListAllFiles() async throws {
    let ref = storage.reference(withPath: "ios/public/list")
    let listResult = try await ref.listAll()
    XCTAssertEqual(listResult.items, [ref.child("a"), ref.child("b")])
    XCTAssertEqual(listResult.prefixes, [ref.child("prefix")])
    XCTAssertNil(listResult.pageToken, "pageToken should be nil")
  }

  private func waitForExpectations() {
    let kFIRStorageIntegrationTestTimeout = 60.0
    waitForExpectations(timeout: kFIRStorageIntegrationTestTimeout,
                        handler: { (error) -> Void in
                          if let error = error {
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
