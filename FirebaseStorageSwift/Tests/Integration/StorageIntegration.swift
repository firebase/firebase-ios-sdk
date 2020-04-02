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

import FirebaseCore
import FirebaseStorage
import FirebaseStorageSwift
import XCTest

class StorageIntegration: XCTestCase {
  var app: FirebaseApp!
  var storage: Storage!
  static var once = false

  override class func setUp() {
    FirebaseApp.configure()
  }

  override func setUp() {
    super.setUp()
    app = FirebaseApp.app()
    storage = Storage.storage(app: app!)

    if !StorageIntegration.once {
      StorageIntegration.once = true
      let setupExpectation = expectation(description: "setUp")

      let largeFiles = ["ios/public/1mb"]
      let emptyFiles =
        ["ios/public/empty", "ios/public/list/a", "ios/public/list/b", "ios/public/list/prefix/c"]
      setupExpectation.expectedFulfillmentCount = largeFiles.count + emptyFiles.count

      do {
        let bundle = Bundle(for: StorageIntegration.self)
        let filePath = try XCTUnwrap(bundle.path(forResource: "1mb", ofType: "dat"),
                                     "Failed to get filePath")
        let data = try XCTUnwrap(try Data(contentsOf: URL(fileURLWithPath: filePath)),
                                 "Failed to load file")

        for largeFile in largeFiles {
          let ref = storage.reference().child(largeFile)
          ref.putData(data) { result in
            self.assertResultSuccess(result)
            setupExpectation.fulfill()
          }
        }
        for emptyFile in emptyFiles {
          let ref = storage.reference().child(emptyFile)
          ref.putData(data) { result in
            self.assertResultSuccess(result)
            setupExpectation.fulfill()
          }
        }
        waitForExpectations()
      } catch {
        XCTFail("Error thrown setting up files in setUp")
      }
    }
  }

  override func tearDown() {
    app = nil
    storage = nil
    super.tearDown()
  }

  func testUnauthenticatedGetMetadata() {
    let expectation = self.expectation(description: "testUnauthenticatedGetMetadata")
    let ref = storage.reference().child("ios/public/1mb")
    ref.getMetadata { result in
      self.assertResultSuccess(result)
      expectation.fulfill()
    }
    waitForExpectations()
  }

  func testUnauthenticatedUpdateMetadata() {
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

  func testUnauthenticatedDelete() throws {
    let expectation = self.expectation(description: #function)
    let ref = storage.reference(withPath: "ios/public/fileToDelete")
    let data = try XCTUnwrap("Hello Swift World".data(using: .utf8), "Data construction failed")
    ref.putData(data) { result in
      self.assertResultSuccess(result)
      ref.delete { error in
        XCTAssertNil(error, "Error should be nil")
      }
      expectation.fulfill()
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

  func testUnauthenticatedSimplePutData() throws {
    let expectation = self.expectation(description: #function)
    let ref = storage.reference(withPath: "ios/public/testBytesUpload")
    let data = try XCTUnwrap("Hello Swift World".data(using: .utf8), "Data construction failed")
    ref.putData(data) { result in
      self.assertResultSuccess(result)
      expectation.fulfill()
    }
    waitForExpectations()
  }

  func testUnauthenticatedSimplePutSpecialCharacter() throws {
    let expectation = self.expectation(description: #function)
    let ref = storage.reference(withPath: "ios/public/-._~!$'()*,=:@&+;")
    let data = try XCTUnwrap("Hello Swift World".data(using: .utf8), "Data construction failed")
    ref.putData(data) { result in
      self.assertResultSuccess(result)
      expectation.fulfill()
    }
    waitForExpectations()
  }

  func testUnauthenticatedSimplePutDataInBackgroundQueue() throws {
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

  func testUnauthenticatedSimplePutEmptyData() {
    let expectation = self.expectation(description: #function)
    let ref = storage.reference(withPath: "ios/public/testUnauthenticatedSimplePutEmptyData")
    let data = Data()
    ref.putData(data) { result in
      self.assertResultSuccess(result)
      expectation.fulfill()
    }
    waitForExpectations()
  }

  func testUnauthenticatedSimplePutDataUnauthorized() throws {
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

  func testUnauthenticatedSimplePutDataUnauthorizedThrow() throws {
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

  func testUnauthenticatedSimplePutFile() throws {
    let expectation = self.expectation(description: #function)
    let putFileExpectation = self.expectation(description: "putFile")
    let ref = storage.reference(withPath: "ios/public/testUnauthenticatedSimplePutFile")
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

  func testUnauthenticatedSimplePutDataNoMetadata() throws {
    let expectation = self.expectation(description: #function)

    let ref = storage.reference(withPath: "ios/public/testUnauthenticatedSimplePutDataNoMetadata")
    let data = try XCTUnwrap("Hello Swift World".data(using: .utf8), "Data construction failed")

    ref.putData(data) { result in
      self.assertResultSuccess(result)
      expectation.fulfill()
    }
    waitForExpectations()
  }

  func testUnauthenticatedSimplePutFileNoMetadata() throws {
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

  func testUnauthenticatedSimpleGetData() {
    let expectation = self.expectation(description: #function)

    let ref = storage.reference(withPath: "ios/public/1mb")
    ref.getData(maxSize: 1024 * 1024) { result in
      self.assertResultSuccess(result)
      expectation.fulfill()
    }
    waitForExpectations()
  }

  func testUnauthenticatedSimpleGetDataInBackgroundQueue() {
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

  func testUnauthenticatedSimpleGetDataTooSmall() {
    let expectation = self.expectation(description: #function)

    let ref = storage.reference(withPath: "ios/public/1mb")
    ref.getData(maxSize: 1024) { result in
      switch result {
      case .success:
        XCTFail("Unexpected success from getData too small")
      case let .failure(error as NSError):
        XCTAssertEqual(error.code, StorageErrorCode.downloadSizeExceeded.rawValue)
      }
      expectation.fulfill()
    }
    waitForExpectations()
  }

  func testUnauthenticatedSimpleGetDownloadURL() {
    let expectation = self.expectation(description: #function)

    let ref = storage.reference(withPath: "ios/public/1mb")

    // Download URL format is
    // "https://firebasestorage.googleapis.com/v0/b/{bucket}/o/{path}?alt=media&token={token}"
    let downloadURLPattern =
      "^https:\\/\\/firebasestorage.googleapis.com\\/v0\\/b\\/[^\\/]*\\/o\\/" +
      "ios%2Fpublic%2F1mb\\?alt=media&token=[a-z0-9-]*$"

    ref.downloadURL { result in
      switch result {
      case let .success(downloadURL):
        do {
          let testRegex = try NSRegularExpression(pattern: downloadURLPattern)
          let urlString = downloadURL.absoluteString
          XCTAssertEqual(testRegex.numberOfMatches(in: urlString,
                                                   range: NSRange(location: 0,
                                                                  length: urlString.count)), 1)
        } catch {
          XCTFail("Throw in downloadURL completion block")
        }
      case let .failure(error):
        XCTFail("Unexpected error \(error) from downloadURL")
      }
      expectation.fulfill()
    }
    waitForExpectations()
  }

  func testUnauthenticatedSimpleGetFile() throws {
    let expectation = self.expectation(description: #function)
    let ref = storage.reference(withPath: "ios/public/helloworld")
    let tmpDirURL = URL(fileURLWithPath: NSTemporaryDirectory())
    let fileURL = tmpDirURL.appendingPathComponent("hello.txt")
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

  func testUpdateMetadata() {
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

  func testPagedListFiles() {
    let expectation = self.expectation(description: #function)
    let ref = storage.reference(withPath: "ios/public/list")

    ref.list(withMaxResults: 2) { result in
      switch result {
      case let .success(listResult):
        XCTAssertEqual(listResult.items, [ref.child("a"), ref.child("b")])
        XCTAssertEqual(listResult.prefixes, [])
        guard let pageToken = listResult.pageToken else {
          XCTFail("pageToken should not be nil")
          expectation.fulfill()
          return
        }
        ref.list(withMaxResults: 2, pageToken: pageToken) { result in
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
    let kFIRStorageIntegrationTestTimeout = 60.0
    waitForExpectations(timeout: kFIRStorageIntegrationTestTimeout,
                        handler: { (error) -> Void in
                          if let error = error {
                            print(error)
                          }
    })
  }

  private func assertResultSuccess<T>(
    _ result: Result<T, Error>,
    file: StaticString = #file, line: UInt = #line
  ) {
    switch result {
    case let .success(value):
      XCTAssertNotNil(value, file: file, line: line)
    case let .failure(error):
      XCTFail("Unexpected error \(error)")
    }
  }
}
