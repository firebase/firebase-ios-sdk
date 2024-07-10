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

//
// Firebase Storage Integration tests
//
// To run these tests, you need to define the following access rights:
// *
//  rules_version = '2';
//  service firebase.storage {
//    match /b/{bucket}/o {
//      match /{directChild=*} {
//        allow read: if request.auth != null;
//      }
//      match /ios {
//        match /public/{allPaths=**} {
//          allow write: if request.auth != null;
//          allow read: if true;
//        }
//        match /private/{allPaths=**} {
//          allow read, write: if false;
//        }
//      }
//    }
//  }
//
// You also need to enable email/password sign in and add a test user in your
// Firebase Authentication settings. Your account credentials need to match
// the credentials defined in `kTestUser` and `kTestPassword` in Credentials.swift.
//
// You can define these access rights in the Firebase Console of your project.
//

import Combine
import FirebaseAuth
import FirebaseCombineSwift
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
      StorageIntegration.once = true
      let setupExpectation = expectation(description: "setUp")

      let largeFiles = ["ios/public/1mb"]
      let emptyFiles =
        ["ios/public/empty", "ios/public/list/a", "ios/public/list/b", "ios/public/list/prefix/c"]
      setupExpectation.expectedFulfillmentCount = largeFiles.count + emptyFiles.count

      do {
        var cancellables = Set<AnyCancellable>()
        let bundle = Bundle(for: StorageIntegration.self)
        let filePath = try XCTUnwrap(bundle.path(forResource: "1mb", ofType: "dat"),
                                     "Failed to get filePath")
        let data = try XCTUnwrap(Data(contentsOf: URL(fileURLWithPath: filePath)),
                                 "Failed to load file")

        for file in largeFiles + emptyFiles {
          storage
            .reference()
            .child(file)
            .putData(data)
            .assertNoFailure()
            .sink { _ in
              setupExpectation.fulfill()
            }
            .store(in: &cancellables)
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

  func testGetMetadata() {
    var cancellables = Set<AnyCancellable>()
    let expectation = self.expectation(description: "testGetMetadata")
    storage.reference().child("ios/public/1mb")
      .getMetadata()
      .assertNoFailure()
      .sink { metadata in
        XCTAssertNotNil(metadata)
        expectation.fulfill()
      }
      .store(in: &cancellables)

    waitForExpectations()
  }

  func testUpdateMetadata() {
    var cancellables = Set<AnyCancellable>()
    let expectation = self.expectation(description: #function)
    let meta = StorageMetadata()
    meta.contentType = "lol/custom"
    meta.customMetadata = ["lol": "custom metadata is neat",
                           "ちかてつ": "🚇",
                           "shinkansen": "新幹線"]

    storage.reference(withPath: "ios/public/1mb")
      .updateMetadata(meta)
      .assertNoFailure()
      .sink { metadata in
        XCTAssertEqual(meta.contentType, metadata.contentType)
        XCTAssertEqual(meta.customMetadata!["lol"], metadata.customMetadata!["lol"])
        XCTAssertEqual(meta.customMetadata!["ちかてつ"], metadata.customMetadata!["ちかてつ"])
        XCTAssertEqual(meta.customMetadata!["shinkansen"],
                       metadata.customMetadata!["shinkansen"])
        expectation.fulfill()
      }
      .store(in: &cancellables)

    waitForExpectations()
  }

  func testDelete() throws {
    var cancellables = Set<AnyCancellable>()
    let expectation = self.expectation(description: #function)
    let ref = storage.reference(withPath: "ios/public/fileToDelete")
    let data = try XCTUnwrap("Hello Swift World".data(using: .utf8), "Data construction failed")
    ref.putData(data)
      .flatMap { _ in ref.delete() }
      .assertNoFailure()
      .sink { success in
        XCTAssertTrue(success)
        expectation.fulfill()
      }
      .store(in: &cancellables)

    waitForExpectations()
  }

  func testDeleteWithNilCompletion() throws {
    var cancellables = Set<AnyCancellable>()
    let expectation = self.expectation(description: #function)
    let ref = storage.reference(withPath: "ios/public/fileToDelete")
    let data = try XCTUnwrap("Hello Swift World".data(using: .utf8), "Data construction failed")
    ref.putData(data)
      .assertNoFailure()
      .sink { metadata in
        XCTAssertEqual(metadata.name, "fileToDelete")
        ref.delete(completion: nil)
        expectation.fulfill()
      }
      .store(in: &cancellables)

    waitForExpectations()
  }

  func testSimplePutData() throws {
    var cancellables = Set<AnyCancellable>()
    let expectation = self.expectation(description: #function)
    let data = try XCTUnwrap("Hello Swift World".data(using: .utf8), "Data construction failed")
    storage.reference(withPath: "ios/public/testBytesUpload")
      .putData(data)
      .assertNoFailure()
      .sink { metadata in
        XCTAssertEqual(metadata.name, "testBytesUpload")
        XCTAssertEqual(metadata.contentEncoding, "identity")
        expectation.fulfill()
      }
      .store(in: &cancellables)

    waitForExpectations()
  }

  func testSimplePutSpecialCharacter() throws {
    var cancellables = Set<AnyCancellable>()
    let expectation = self.expectation(description: #function)
    let data = try XCTUnwrap("Hello Swift World".data(using: .utf8), "Data construction failed")
    let path = "ios/public/-._~!$'()*,=:@&+;"
    storage.reference(withPath: path)
      .putData(data)
      .assertNoFailure()
      .sink { metadata in
        XCTAssertEqual(metadata.contentType, "application/octet-stream")
        expectation.fulfill()
      }
      .store(in: &cancellables)
    waitForExpectations()
  }

  func testSimplePutDataInBackgroundQueue() throws {
    var cancellables = Set<AnyCancellable>()
    let expectation = self.expectation(description: #function)
    let data = try XCTUnwrap("Hello Swift World".data(using: .utf8), "Data construction failed")
    storage.reference(withPath: "ios/public/testBytesUpload")
      .putData(data)
      .subscribe(on: DispatchQueue.global(qos: .background))
      .assertNoFailure()
      .sink { _ in
        expectation.fulfill()
      }
      .store(in: &cancellables)

    waitForExpectations()
  }

  func testSimplePutEmptyData() {
    var cancellables = Set<AnyCancellable>()
    let expectation = self.expectation(description: #function)
    storage
      .reference(withPath: "ios/public/testSimplePutEmptyData")
      .putData(Data())
      .assertNoFailure()
      .sink { _ in
        expectation.fulfill()
      }
      .store(in: &cancellables)
    waitForExpectations()
  }

  func testSimplePutDataUnauthorized() throws {
    var cancellables = Set<AnyCancellable>()
    let expectation = self.expectation(description: #function)
    let data = try XCTUnwrap("Hello Swift World".data(using: .utf8), "Data construction failed")

    storage
      .reference(withPath: "ios/private/secretfile.txt")
      .putData(data)
      .sink(receiveCompletion: { completion in
        switch completion {
        case .finished:
          XCTFail("Unexpected success return from putData)")
        case let .failure(error):
          let message = String(describing: error)
          XCTAssertTrue(message.contains("unauthorized"))
          XCTAssertTrue(message.contains("ios-opensource-samples.appspot.com"))
          expectation.fulfill()
        }
      }, receiveValue: { value in
        print("Received value \(value)")
      })
      .store(in: &cancellables)

    waitForExpectations()
  }

  func testAttemptToUploadDirectoryShouldFail() throws {
    let expectation = self.expectation(description: #function)
    var cancellables = Set<AnyCancellable>()
    // This `.numbers` file is actually a directory.
    let fileName = "HomeImprovement.numbers"
    let bundle = Bundle(for: StorageIntegration.self)
    let fileURL = try XCTUnwrap(bundle.url(forResource: fileName, withExtension: ""),
                                "Failed to get filePath")
    storage
      .reference(withPath: "ios/public/" + fileName)
      .putFile(from: fileURL)
      .sink(receiveCompletion: { completion in
        switch completion {
        case .finished:
          XCTFail("Unexpected success return from putFile)")
        case let .failure(error):
          XCTAssertTrue(String(describing: error).starts(with: "unknown"))
          expectation.fulfill()
        }
      }, receiveValue: { value in
        print("Received value \(value)")
      })
      .store(in: &cancellables)

    waitForExpectations()
  }

  func testPutFileWithSpecialCharacters() throws {
    var cancellables = Set<AnyCancellable>()
    let expectation = self.expectation(description: #function)
    let fileName = "hello&+@_ .txt"
    let data = try XCTUnwrap("Hello Swift World".data(using: .utf8), "Data construction failed")
    let tmpDirURL = URL(fileURLWithPath: NSTemporaryDirectory())
    let fileURL = tmpDirURL.appendingPathComponent("hello.txt")
    try data.write(to: fileURL, options: .atomicWrite)
    let ref = storage.reference(withPath: "ios/public/" + fileName)

    ref
      .putFile(from: fileURL)
      .assertNoFailure()
      .sink { _ in
        ref
          .getMetadata()
          .assertNoFailure()
          .sink { metadata in
            XCTAssertNotNil(metadata)
            expectation.fulfill()
          }
          .store(in: &cancellables)
      }
      .store(in: &cancellables)

    waitForExpectations()
  }

  func testSimplePutDataNoMetadata() throws {
    var cancellables = Set<AnyCancellable>()
    let expectation = self.expectation(description: #function)
    let data = try XCTUnwrap("Hello Swift World".data(using: .utf8), "Data construction failed")

    storage
      .reference(withPath: "ios/public/testSimplePutDataNoMetadata")
      .putData(data)
      .assertNoFailure()
      .sink { metadata in
        XCTAssertNotNil(metadata)
        expectation.fulfill()
      }
      .store(in: &cancellables)

    waitForExpectations()
  }

  func testSimplePutFileNoMetadata() throws {
    var cancellables = Set<AnyCancellable>()
    let expectation = self.expectation(description: #function)
    let fileName = "hello&+@_ .txt"
    let data = try XCTUnwrap("Hello Swift World".data(using: .utf8), "Data construction failed")
    let tmpDirURL = URL(fileURLWithPath: NSTemporaryDirectory())
    let fileURL = tmpDirURL.appendingPathComponent("hello.txt")
    try data.write(to: fileURL, options: .atomicWrite)
    storage
      .reference(withPath: "ios/public/" + fileName)
      .putFile(from: fileURL)
      .assertNoFailure()
      .sink { metadata in
        XCTAssertNotNil(metadata)
        expectation.fulfill()
      }
      .store(in: &cancellables)

    waitForExpectations()
  }

  func testSimpleGetData() {
    var cancellables = Set<AnyCancellable>()
    let expectation = self.expectation(description: #function)
    storage
      .reference(withPath: "ios/public/1mb")
      .getData(maxSize: 1024 * 1024)
      .assertNoFailure()
      .sink { _ in
        expectation.fulfill()
      }
      .store(in: &cancellables)

    waitForExpectations()
  }

  func testSimpleGetDataInBackgroundQueue() {
    var cancellables = Set<AnyCancellable>()
    let expectation = self.expectation(description: #function)
    storage
      .reference(withPath: "ios/public/1mb")
      .getData(maxSize: 1024 * 1024)
      .subscribe(on: DispatchQueue.global(qos: .background))
      .assertNoFailure()
      .sink { _ in
        expectation.fulfill()
      }
      .store(in: &cancellables)

    waitForExpectations()
  }

  func testSimpleGetDataWithCustomCallbackQueue() {
    var cancellables = Set<AnyCancellable>()
    let expectation = self.expectation(description: #function)
    let callbackQueueLabel = "customCallbackQueue"
    let callbackQueueKey = DispatchSpecificKey<String>()
    let callbackQueue = DispatchQueue(label: callbackQueueLabel)
    callbackQueue.setSpecific(key: callbackQueueKey, value: callbackQueueLabel)
    storage.callbackQueue = callbackQueue

    storage
      .reference(withPath: "ios/public/1mb")
      .getData(maxSize: 1024 * 1024)
      .assertNoFailure()
      .sink { _ in
        XCTAssertFalse(Thread.isMainThread)

        let currentQueueLabel = DispatchQueue.getSpecific(key: callbackQueueKey)
        XCTAssertEqual(currentQueueLabel, callbackQueueLabel)

        expectation.fulfill()

        // Reset the callbackQueue to default (main queue).
        self.storage.callbackQueue = DispatchQueue.main
        callbackQueue.setSpecific(key: callbackQueueKey, value: nil)
      }
      .store(in: &cancellables)

    waitForExpectations()
  }

  func testSimpleGetDataTooSmall() {
    var cancellables = Set<AnyCancellable>()
    let expectation = self.expectation(description: #function)

    storage
      .reference(withPath: "ios/public/1mb")
      .getData(maxSize: 1024)
      .sink(receiveCompletion: { completion in
        switch completion {
        case .finished:
          XCTFail("Unexpected success return from getData)")
        case let .failure(error):
          let message = String(describing: error)
          XCTAssertTrue(message.contains("downloadSizeExceeded"))
          XCTAssertTrue(message.contains("1048576"))
          XCTAssertTrue(message.contains("1024"))
          expectation.fulfill()
        }
      }, receiveValue: { value in
        print("Received value \(value)")
      })
      .store(in: &cancellables)

    waitForExpectations()
  }

  func testSimpleGetDownloadURL() {
    var cancellables = Set<AnyCancellable>()
    let expectation = self.expectation(description: #function)

    // Download URL format is
    // "https://firebasestorage.googleapis.com/v0/b/{bucket}/o/{path}?alt=media&token={token}"
    let downloadURLPattern =
      "^https:\\/\\/firebasestorage.googleapis.com:443\\/v0\\/b\\/[^\\/]*\\/o\\/" +
      "ios%2Fpublic%2F1mb\\?alt=media&token=[a-z0-9-]*$"

    storage
      .reference(withPath: "ios/public/1mb")
      .downloadURL()
      .assertNoFailure()
      .sink { downloadURL in
        do {
          let testRegex = try NSRegularExpression(pattern: downloadURLPattern)
          let downloadURL = try XCTUnwrap(downloadURL, "Failed to unwrap downloadURL")
          let urlString = downloadURL.absoluteString
          XCTAssertEqual(testRegex.numberOfMatches(in: urlString,
                                                   range: NSRange(location: 0,
                                                                  length: urlString.count)), 1)
        } catch {
          XCTFail("Throw in downloadURL completion block")
        }
        expectation.fulfill()
      }
      .store(in: &cancellables)

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
    var cancellables = Set<AnyCancellable>()
    let expectation = self.expectation(description: #function)

    let metadata = StorageMetadata()
    metadata.cacheControl = "cache-control"
    metadata.contentDisposition = "content-disposition"
    metadata.contentEncoding = "gzip"
    metadata.contentLanguage = "de"
    metadata.contentType = "content-type-a"
    metadata.customMetadata = ["a": "b"]

    let ref = storage.reference(withPath: "ios/public/1mb")
    ref
      .updateMetadata(metadata)
      .assertNoFailure()
      .sink { updatedMetadata in
        self.assertMetadata(actualMetadata: updatedMetadata,
                            expectedContentType: "content-type-a",
                            expectedCustomMetadata: ["a": "b"])

        let metadata = updatedMetadata
        metadata.contentType = "content-type-b"
        metadata.customMetadata = ["a": "b", "c": "d"]

        ref
          .updateMetadata(metadata)
          .assertNoFailure()
          .sink { updatedMetadata in
            self.assertMetadata(actualMetadata: updatedMetadata,
                                expectedContentType: "content-type-b",
                                expectedCustomMetadata: ["a": "b", "c": "d"])
            metadata.cacheControl = nil
            metadata.contentDisposition = nil
            metadata.contentEncoding = nil
            metadata.contentLanguage = nil
            metadata.contentType = nil
            metadata.customMetadata = nil

            ref
              .updateMetadata(metadata)
              .assertNoFailure()
              .sink { _ in
                expectation.fulfill()
              }
              .store(in: &cancellables)
          }
          .store(in: &cancellables)
      }
      .store(in: &cancellables)

    waitForExpectations()
  }

  func testPagedListFiles() {
    var cancellables = Set<AnyCancellable>()
    let expectation = self.expectation(description: #function)
    let ref = storage.reference(withPath: "ios/public/list")

    ref
      .list(maxResults: 2)
      .assertNoFailure()
      .sink { listResult in
        XCTAssertEqual(listResult.items, [ref.child("a"), ref.child("b")])
        XCTAssertEqual(listResult.prefixes, [])
        guard let pageToken = listResult.pageToken else {
          XCTFail("pageToken should not be nil")
          expectation.fulfill()
          return
        }
        ref
          .list(maxResults: 2, pageToken: pageToken)
          .assertNoFailure()
          .sink { listResult in
            XCTAssertEqual(listResult.items, [])
            XCTAssertEqual(listResult.prefixes, [ref.child("prefix")])
            XCTAssertNil(listResult.pageToken, "pageToken should be nil")
            expectation.fulfill()
          }
          .store(in: &cancellables)
      }
      .store(in: &cancellables)

    waitForExpectations()
  }

  func testListAllFiles() {
    var cancellables = Set<AnyCancellable>()
    let expectation = self.expectation(description: #function)
    let ref = storage.reference(withPath: "ios/public/list")

    ref
      .listAll()
      .assertNoFailure()
      .sink { listResult in
        XCTAssertEqual(listResult.items, [ref.child("a"), ref.child("b")])
        XCTAssertEqual(listResult.prefixes, [ref.child("prefix")])
        XCTAssertNil(listResult.pageToken, "pageToken should be nil")
        expectation.fulfill()
      }
      .store(in: &cancellables)

    waitForExpectations()
  }

  private func signInAndWait() {
    var cancellables = Set<AnyCancellable>()
    let expectation = self.expectation(description: #function)
    auth
      .signIn(withEmail: Credentials.kUserName,
              password: Credentials.kPassword)
      .assertNoFailure()
      .sink { _ in
        StorageIntegration.signedIn = true
        print("Successfully signed in")
        expectation.fulfill()
      }
      .store(in: &cancellables)

    waitForExpectations()
  }

  private func waitForExpectations() {
    let kFIRStorageIntegrationTestTimeout = 30.0
    waitForExpectations(timeout: kFIRStorageIntegrationTestTimeout,
                        handler: { error in
                          if let error {
                            print(error)
                          }
                        })
  }
}
