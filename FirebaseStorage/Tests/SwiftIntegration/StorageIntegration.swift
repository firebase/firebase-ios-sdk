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

// See console setup instructions in FIRStorageIntegrationTests.m

import FirebaseAuth
import FirebaseCore
import FirebaseStorage
import XCTest

class StorageIntegration: XCTestCase {
  var app: FirebaseApp!
  var auth: Auth!
  var storage: Storage!
  static var once = false
  static var signedIn = false

  override class func setUp() {
    FirebaseApp.configure()
  }

  override func setUp() {
    super.setUp()
    app = FirebaseApp.app()
    auth = Auth.auth(app: app)
    storage = Storage.storage(app: app!)

    if !StorageIntegration.signedIn {
      signInAndWait()
    }

    if !StorageIntegration.once {
      let setupExpectation = expectation(description: "setUp")

      let largeFiles = ["ios/public/swift-1mb"]
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
          ref.putData(data, metadata: nil, completion: { _, error in
            XCTAssertNil(error, "Error should be nil")
            setupExpectation.fulfill()
          })
        }
        for emptyFile in emptyFiles {
          let ref = storage.reference().child(emptyFile)
          ref.putData(Data(), metadata: nil, completion: { _, error in
            XCTAssertNil(error, "Error should be nil")
            setupExpectation.fulfill()
          })
        }

      } catch {
        XCTFail("Exception thrown setting up files in setUp")
      }
      waitForExpectations()
      StorageIntegration.once = true
    }
  }

  override func tearDown() {
    app = nil
    auth = nil
    storage = nil
    super.tearDown()
  }

  func testName() {
    let aGS = app.options.projectID
    let aGSURI = "gs://\(aGS!).appspot.com/path/to"
    let ref = storage.reference(forURL: aGSURI)
    XCTAssertEqual(ref.description, aGSURI)
  }

  func testGetMetadata() {
    let expectation = self.expectation(description: #function)
    let ref = storage.reference().child("ios/public/1mb")
    ref.getMetadata(completion: { (metadata, error) -> Void in
      XCTAssertNotNil(metadata, "Metadata should not be nil")
      XCTAssertNil(error, "Error should be nil")
      expectation.fulfill()
    })
    waitForExpectations()
  }

  func testGetMetadataUnauthorized() {
    let expectation = self.expectation(description: #function)
    let ref = storage.reference().child("ios/private/secretfile.txt")
    ref.getMetadata(completion: { (metadata, error) -> Void in
      XCTAssertNil(metadata, "Metadata should be nil")
      XCTAssertNotNil(error, "Error should not be nil")
      XCTAssertEqual((error! as NSError).code, StorageErrorCode.unauthorized.rawValue)
      expectation.fulfill()
    })
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
    ref.updateMetadata(meta, completion: { metadata, error in
      XCTAssertEqual(meta.contentType, metadata!.contentType)
      XCTAssertEqual(meta.customMetadata!["lol"], metadata?.customMetadata!["lol"])
      XCTAssertEqual(meta.customMetadata!["ちかてつ"], metadata?.customMetadata!["ちかてつ"])
      XCTAssertEqual(meta.customMetadata!["shinkansen"],
                     metadata?.customMetadata!["shinkansen"])
      XCTAssertNil(error, "Error should be nil")
      expectation.fulfill()
    })
    waitForExpectations()
  }

  func testDelete() throws {
    let expectation = self.expectation(description: #function)
    let ref = storage.reference(withPath: "ios/public/fileToDelete")
    let data = try XCTUnwrap("Hello Swift World".data(using: .utf8), "Data construction failed")
    ref.putData(data, metadata: nil, completion: { metadata, error in
      XCTAssertNotNil(metadata, "Metadata should not be nil")
      XCTAssertNil(error, "Error should be nil")
      ref.delete(completion: { error in
        XCTAssertNil(error, "Error should be nil")
        expectation.fulfill()
      })
    })
    waitForExpectations()
  }

  func testDeleteNonExistingFile() {
    let expectation = self.expectation(description: #function)
    let ref = storage.reference(withPath: "ios/public/fileThatDoesNotExist")
    ref.delete { error in
      XCTAssertNotNil(error, "Error should not be nil")
      XCTAssertEqual((error! as NSError).code, StorageErrorCode.objectNotFound.rawValue)
      expectation.fulfill()
    }
    waitForExpectations()
  }

  func testDeleteFileUnauthorized() {
    let expectation = self.expectation(description: #function)
    let ref = storage.reference(withPath: "ios/private/secretfile.txt")
    ref.delete { error in
      XCTAssertNotNil(error, "Error should not be nil")
      XCTAssertEqual((error! as NSError).code, StorageErrorCode.unauthorized.rawValue)
      expectation.fulfill()
    }
    waitForExpectations()
  }

  func testDeleteWithNilCompletion() throws {
    let expectation = self.expectation(description: #function)
    let ref = storage.reference(withPath: "ios/public/fileToDelete")
    let data = try XCTUnwrap("Hello Swift World".data(using: .utf8), "Data construction failed")
    ref.putData(data, metadata: nil, completion: { metadata, error in
      XCTAssertNotNil(metadata, "Metadata should not be nil")
      XCTAssertNil(error, "Error should be nil")
      ref.delete(completion: nil)
      expectation.fulfill()
    })
    waitForExpectations()
  }

  func testSimplePutData() throws {
    let expectation = self.expectation(description: #function)
    let ref = storage.reference(withPath: "ios/public/testBytesUpload")
    let data = try XCTUnwrap("Hello Swift World".data(using: .utf8), "Data construction failed")
    ref.putData(data, metadata: nil, completion: { metadata, error in
      XCTAssertNotNil(metadata, "Metadata should not be nil")
      XCTAssertNil(error, "Error should be nil")
      expectation.fulfill()
    })
    waitForExpectations()
  }

  func testSimplePutSpecialCharacter() throws {
    let expectation = self.expectation(description: #function)
    let ref = storage.reference(withPath: "ios/public/-._~!$'()*,=:@&+;")
    let data = try XCTUnwrap("Hello Swift World".data(using: .utf8), "Data construction failed")
    ref.putData(data, metadata: nil, completion: { metadata, error in
      XCTAssertNotNil(metadata, "Metadata should not be nil")
      XCTAssertNil(error, "Error should be nil")
      expectation.fulfill()
    })
    waitForExpectations()
  }

  func testSimplePutDataInBackgroundQueue() throws {
    let expectation = self.expectation(description: #function)
    let ref = storage.reference(withPath: "ios/public/testBytesUpload")
    let data = try XCTUnwrap("Hello Swift World".data(using: .utf8), "Data construction failed")
    DispatchQueue.global(qos: .background).async {
      ref.putData(data, metadata: nil, completion: { metadata, error in
        XCTAssertNotNil(metadata, "Metadata should not be nil")
        XCTAssertNil(error, "Error should be nil")
        expectation.fulfill()
      })
    }
    waitForExpectations()
  }

  func testSimplePutEmptyData() {
    let expectation = self.expectation(description: #function)
    let ref = storage.reference(withPath: "ios/public/testSimplePutEmptyData")
    let data = Data()
    ref.putData(data, metadata: nil, completion: { metadata, error in
      XCTAssertNotNil(metadata, "Metadata should not be nil")
      XCTAssertNil(error, "Error should be nil")
      expectation.fulfill()
    })
    waitForExpectations()
  }

  func testSimplePutDataUnauthorized() throws {
    let expectation = self.expectation(description: #function)
    let ref = storage.reference(withPath: "ios/private/secretfile.txt")
    let data = try XCTUnwrap("Hello Swift World".data(using: .utf8), "Data construction failed")
    ref.putData(data, metadata: nil, completion: { metadata, error in
      XCTAssertNil(metadata, "Metadata should be nil")
      XCTAssertNotNil(error, "Error should not be nil")
      XCTAssertEqual((error! as NSError).code, StorageErrorCode.unauthorized.rawValue)
      expectation.fulfill()
    })
    waitForExpectations()
  }

  func testSimplePutFile() throws {
    let expectation = self.expectation(description: #function)
    let ref = storage.reference(withPath: "ios/public/testSimplePutFile")
    let data = try XCTUnwrap("Hello Swift World".data(using: .utf8), "Data construction failed")
    let tmpDirURL = URL(fileURLWithPath: NSTemporaryDirectory())
    let fileURL = tmpDirURL.appendingPathComponent("hello.txt")
    try data.write(to: fileURL, options: .atomicWrite)
    let task = ref.putFile(from: fileURL, metadata: nil, completion: { metadata, error in
      XCTAssertNotNil(metadata, "Metadata should not be nil")
      XCTAssertNil(error, "Error should be nil")
    })

    task.observe(StorageTaskStatus.success, handler: { snapshot in
      XCTAssertEqual(snapshot.description, "<State: Success>")
      expectation.fulfill()
    })

    var uploadedBytes: Int64 = -1

    task.observe(StorageTaskStatus.progress, handler: { snapshot in
      XCTAssertTrue(snapshot.description.starts(with: "<State: Progress") ||
        snapshot.description.starts(with: "<State: Resume"))
      guard let progress = snapshot.progress else {
        XCTFail("Failed to get snapshot.progress")
        return
      }
      XCTAssertGreaterThanOrEqual(progress.completedUnitCount, uploadedBytes)
      uploadedBytes = progress.completedUnitCount
    })
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
    ref.putFile(from: fileURL, metadata: nil, completion: { metadata, error in
      XCTAssertNotNil(metadata, "Metadata should not be nil")
      XCTAssertNil(error, "Error should be nil")
      XCTAssertEqual(fileName, metadata?.name)
      ref.getMetadata(completion: { metadata, error in
        XCTAssertNotNil(metadata, "Metadata should not be nil")
        XCTAssertNil(error, "Error should be nil")
        XCTAssertEqual(fileName, metadata?.name)
        expectation.fulfill()
      })
    })
    waitForExpectations()
  }

  func testSimplePutDataNoMetadata() throws {
    let expectation = self.expectation(description: #function)

    let ref = storage.reference(withPath: "ios/public/testSimplePutDataNoMetadata")
    let data = try XCTUnwrap("Hello Swift World".data(using: .utf8), "Data construction failed")
    ref.putData(data, metadata: nil, completion: { metadata, error in
      XCTAssertNotNil(metadata, "Metadata should not be nil")
      XCTAssertNil(error, "Error should be nil")
      expectation.fulfill()
    })
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
    ref.putFile(from: fileURL, metadata: nil, completion: { metadata, error in
      XCTAssertNotNil(metadata, "Metadata should not be nil")
      XCTAssertNil(error, "Error should be nil")
      expectation.fulfill()
    })
    waitForExpectations()
  }

  func testSimplePutBlankImage() throws {
    let expectation = self.expectation(description: #function)
    let fileName = "blank.jpg"
    let ref = storage.reference(withPath: "ios/public/" + fileName)
    let tmpDirURL = URL(fileURLWithPath: NSTemporaryDirectory())
    let imageURL = tmpDirURL.appendingPathComponent(fileName)

    let data = Data()
    try data.write(to: imageURL, options: .atomicWrite)

    ref.putFile(from: imageURL, metadata: nil, completion: { metadata, error in
      XCTAssertNotNil(metadata, "Metadata should not be nil")
      XCTAssertNil(error, "Error should be nil")
      expectation.fulfill()
    })
    waitForExpectations()
  }

  func testSimpleGetData() {
    let expectation = self.expectation(description: #function)

    let ref = storage.reference(withPath: "ios/public/1mb")
    ref.getData(maxSize: 1024 * 1024, completion: { data, error in
      XCTAssertNotNil(data, "Data should not be nil")
      XCTAssertNil(error, "Error should be nil")
      expectation.fulfill()
    })
    waitForExpectations()
  }

  func testSimpleGetDataInBackgroundQueue() {
    let expectation = self.expectation(description: #function)

    let ref = storage.reference(withPath: "ios/public/1mb")
    DispatchQueue.global(qos: .background).async {
      ref.getData(maxSize: 1024 * 1024, completion: { data, error in
        XCTAssertNotNil(data, "Data should not be nil")
        XCTAssertNil(error, "Error should be nil")
        expectation.fulfill()
      })
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
    ref.getData(maxSize: 1024 * 1024) { data, error in
      XCTAssertNotNil(data, "Data should not be nil")
      XCTAssertNil(error, "Error should be nil")

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
    ref.getData(maxSize: 1024, completion: { data, error in
      XCTAssertNil(data, "Data should be nil")
      XCTAssertNotNil(error, "Error should not be nil")
      XCTAssertEqual((error! as NSError).code, StorageErrorCode.downloadSizeExceeded.rawValue)
      expectation.fulfill()
    })
    waitForExpectations()
  }

  func testSimpleGetDownloadURL() {
    let expectation = self.expectation(description: #function)

    let ref = storage.reference(withPath: "ios/public/1mb")

    // Download URL format is
    // "https://firebasestorage.googleapis.com/v0/b/{bucket}/o/{path}?alt=media&token={token}"
    let downloadURLPattern =
      "^https:\\/\\/firebasestorage.googleapis.com\\/v0\\/b\\/[^\\/]*\\/o\\/" +
      "ios%2Fpublic%2F1mb\\?alt=media&token=[a-z0-9-]*$"

    ref.downloadURL(completion: { downloadURL, error in
      XCTAssertNil(error, "Error should be nil")
      do {
        let testRegex = try NSRegularExpression(pattern: downloadURLPattern)
        let downloadURL = try XCTUnwrap(downloadURL, "Failed to unwrap downloadURL")
        let urlString = downloadURL.absoluteString
        XCTAssertEqual(testRegex.numberOfMatches(in: urlString,
                                                 range: NSRange(location: 0,
                                                                length: urlString.count)), 1)
        expectation.fulfill()
      } catch {
        XCTFail("Throw in downloadURL completion block")
      }
    })
    waitForExpectations()
  }

  func testSimpleGetFileWithCompletion() throws {
    let expectation = self.expectation(description: #function)
    let ref = storage.reference(withPath: "ios/public/cookie")
    let cookieString = "Here's a 🍪, yay!"
    let data = try XCTUnwrap(cookieString.data(using: .utf8), "Data construction failed")

    ref.putData(data, metadata: nil, completion: { metadata, error in
      XCTAssertNotNil(metadata, "Metadata should not be nil")
      XCTAssertNil(error, "Error should be nil")

      let tmpDirURL = URL(fileURLWithPath: NSTemporaryDirectory())
      let fileURL = tmpDirURL.appendingPathComponent("cookie.txt")
      ref.write(toFile: fileURL) { url, error in
        XCTAssertNil(error, "Error should be nil")

        guard let url = url else {
          XCTFail("Failed to unwrap url")
          return
        }
        XCTAssertEqual(fileURL, url)

        do {
          let stringData = try String(contentsOf: fileURL, encoding: .utf8)
          XCTAssertEqual(stringData, cookieString)
          expectation.fulfill()
        } catch {
          XCTFail("Could not get String contents of fetched data")
        }
      }
    })
    waitForExpectations()
  }

  func testSimpleGetFile() throws {
    let expectation = self.expectation(description: #function)
    let ref = storage.reference(withPath: "ios/public/helloworld")
    let tmpDirURL = URL(fileURLWithPath: NSTemporaryDirectory())
    let fileURL = tmpDirURL.appendingPathComponent("hello.txt")
    let data = try XCTUnwrap("Hello Swift World".data(using: .utf8), "Data construction failed")

    ref.putData(data, metadata: nil, completion: { metadata, error in
      XCTAssertNotNil(metadata, "Metadata should not be nil")
      XCTAssertNil(error, "Error should be nil")
      let task = ref.write(toFile: fileURL)

      task.observe(StorageTaskStatus.success, handler: { snapshot in
        do {
          let stringData = try String(contentsOf: fileURL, encoding: .utf8)
          XCTAssertEqual(stringData, "Hello Swift World")
          XCTAssertEqual(snapshot.description, "<State: Success>")
          expectation.fulfill()
        } catch {
          XCTFail("Exception processing success snapshot")
        }
      })

      task.observe(StorageTaskStatus.progress, handler: { snapshot in
        XCTAssertNil(snapshot.error, "Error should be nil")
        guard let progress = snapshot.progress else {
          XCTFail("Missing progress")
          return
        }
        print("\(progress.completedUnitCount) of \(progress.totalUnitCount)")
      })
      task.observe(StorageTaskStatus.failure, handler: { snapshot in
        XCTAssertNil(snapshot.error, "Error should be nil")
      })
    })
    waitForExpectations()
  }

  func testCancelDownload() throws {
    let expectation = self.expectation(description: #function)
    let ref = storage.reference(withPath: "ios/public/1mb")
    let tmpDirURL = URL(fileURLWithPath: NSTemporaryDirectory())
    let fileURL = tmpDirURL.appendingPathComponent("hello.dat")
    let task = ref.write(toFile: fileURL)
    var failed = false // Only fail once

    task.observe(StorageTaskStatus.failure, handler: { snapshot in
      XCTAssertTrue(snapshot.description.starts(with: "<State: Failed"))
      if !failed {
        failed = true
        expectation.fulfill()
      }
    })

    task.observe(StorageTaskStatus.progress, handler: { _ in
      task.cancel()
    })
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

    ref.updateMetadata(metadata, completion: { updatedMetadata, error in
      XCTAssertNil(error, "Error should be nil")
      guard let updatedMetadata = updatedMetadata else {
        XCTFail("Metadata is nil")
        return
      }
      self.assertMetadata(actualMetadata: updatedMetadata,
                          expectedContentType: "content-type-a",
                          expectedCustomMetadata: ["a": "b"])

      let metadata = updatedMetadata
      metadata.contentType = "content-type-b"
      metadata.customMetadata = ["a": "b", "c": "d"]

      ref.updateMetadata(metadata, completion: { updatedMetadata, error in
        XCTAssertNil(error, "Error should be nil")
        self.assertMetadata(actualMetadata: updatedMetadata!,
                            expectedContentType: "content-type-b",
                            expectedCustomMetadata: ["a": "b", "c": "d"])
        guard let metadata = updatedMetadata else {
          XCTFail("Metadata is nil")
          return
        }
        metadata.cacheControl = nil
        metadata.contentDisposition = nil
        metadata.contentEncoding = nil
        metadata.contentLanguage = nil
        metadata.contentType = nil
        metadata.customMetadata = Dictionary()
        ref.updateMetadata(metadata, completion: { updatedMetadata, error in
          XCTAssertNil(error, "Error should be nil")
          self.assertMetadataNil(actualMetadata: updatedMetadata!)
          expectation.fulfill()
        })
      })
    })
    waitForExpectations()
  }

  func testResumeGetFile() {
    let expectation = self.expectation(description: #function)
    let ref = storage.reference(withPath: "ios/public/1mb")
    let tmpDirURL = URL(fileURLWithPath: NSTemporaryDirectory())
    let fileURL = tmpDirURL.appendingPathComponent("hello.txt")
    let task = ref.write(toFile: fileURL)

    task.observe(StorageTaskStatus.success, handler: { snapshot in
      XCTAssertEqual(snapshot.description, "<State: Success>")
      expectation.fulfill()
    })

    var resumeAtBytes: Int32 = 256 * 1024
    var downloadedBytes: Int64 = 0
    var computationResult: Double = 0.0

    task.observe(StorageTaskStatus.progress, handler: { snapshot in
      XCTAssertTrue(snapshot.description.starts(with: "<State: Progress") ||
        snapshot.description.starts(with: "<State: Resume"))
      guard let progress = snapshot.progress else {
        XCTFail("Failed to get snapshot.progress")
        return
      }
      XCTAssertGreaterThanOrEqual(progress.completedUnitCount, downloadedBytes)
      downloadedBytes = progress.completedUnitCount
      if progress.completedUnitCount > resumeAtBytes {
        // Making sure the main run loop is busy.
        for i: Int32 in 0 ... 499 {
          DispatchQueue.global(qos: .default).async {
            computationResult = sqrt(Double(INT_MAX - i))
          }
        }
        print("Pausing")
        task.pause()
        resumeAtBytes = INT_MAX
      }
    })

    task.observe(StorageTaskStatus.pause, handler: { snapshot in
      XCTAssertEqual(snapshot.description, "<State: Paused>")
      print("Resuming")
      task.resume()
    })
    waitForExpectations()
    XCTAssertEqual(INT_MAX, resumeAtBytes)
    XCTAssertEqual(sqrt(Double(INT_MAX - 499)), computationResult, accuracy: 0.1)
  }

  func testResumeGetFileInBackgroundQueue() {
    let expectation = self.expectation(description: #function)
    let ref = storage.reference(withPath: "ios/public/1mb")
    let tmpDirURL = URL(fileURLWithPath: NSTemporaryDirectory())
    let fileURL = tmpDirURL.appendingPathComponent("hello.txt")
    let task = ref.write(toFile: fileURL)

    task.observe(StorageTaskStatus.success, handler: { snapshot in
      XCTAssertEqual(snapshot.description, "<State: Success>")
      expectation.fulfill()
    })

    var resumeAtBytes: Int32 = 256 * 1024
    var downloadedBytes: Int64 = 0

    task.observe(StorageTaskStatus.progress, handler: { snapshot in
      XCTAssertTrue(snapshot.description.starts(with: "<State: Progress") ||
        snapshot.description.starts(with: "<State: Resume"))
      guard let progress = snapshot.progress else {
        XCTFail("Failed to get snapshot.progress")
        return
      }
      XCTAssertGreaterThanOrEqual(progress.completedUnitCount, downloadedBytes)
      downloadedBytes = progress.completedUnitCount
      if progress.completedUnitCount > resumeAtBytes {
        print("Pausing")
        DispatchQueue.global(qos: .background).async {
          task.pause()
        }
        resumeAtBytes = INT_MAX
      }
    })

    task.observe(StorageTaskStatus.pause, handler: { snapshot in
      XCTAssertEqual(snapshot.description, "<State: Paused>")
      print("Resuming")
      task.resume()
    })
    waitForExpectations()
    XCTAssertEqual(INT_MAX, resumeAtBytes)
  }

  func testPagedListFiles() {
    let expectation = self.expectation(description: #function)
    let ref = storage.reference(withPath: "ios/public/list")

    ref.list(withMaxResults: 2, completion: { listResult, error in
      XCTAssertNotNil(listResult, "listResult should not be nil")
      XCTAssertNil(error, "Error should be nil")

      XCTAssertEqual(listResult.items, [ref.child("a"), ref.child("b")])
      XCTAssertEqual(listResult.prefixes, [])
      guard let pageToken = listResult.pageToken else {
        XCTFail("pageToken should not be nil")
        return
      }
      ref.list(withMaxResults: 2, pageToken: pageToken, completion: { listResult, error in
        XCTAssertNotNil(listResult, "listResult should not be nil")
        XCTAssertNil(error, "Error should be nil")

        XCTAssertEqual(listResult.items, [])
        XCTAssertEqual(listResult.prefixes, [ref.child("prefix")])
        XCTAssertNil(listResult.pageToken, "pageToken should be nil")
        expectation.fulfill()
      })
    })
    waitForExpectations()
  }

  func testListAllFiles() {
    let expectation = self.expectation(description: #function)
    let ref = storage.reference(withPath: "ios/public/list")

    ref.listAll(completion: { listResult, error in
      XCTAssertNotNil(listResult, "listResult should not be nil")
      XCTAssertNil(error, "Error should be nil")
      XCTAssertEqual(listResult.items, [ref.child("a"), ref.child("b")])
      XCTAssertEqual(listResult.prefixes, [ref.child("prefix")])
      XCTAssertNil(listResult.pageToken, "pageToken should be nil")
      expectation.fulfill()
    })
    waitForExpectations()
  }

  private func signInAndWait() {
    let expectation = self.expectation(description: #function)
    auth.signIn(withEmail: Credentials.kUserName,
                password: Credentials.kPassword) { result, error in
      XCTAssertNil(error)
      StorageIntegration.signedIn = true
      print("Successfully signed in")
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
}
