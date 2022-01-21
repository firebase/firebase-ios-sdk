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

#if swift(>=5.5)
  @available(iOS 15, *)
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
      let result = try await ref.putDataAsync(data)
      XCTAssertNotNil(result)
      _ = try await ref.delete()
      // Next delete should fail and verify the first delete succeeded.
      do {
        _ = try await ref.delete()
      } catch {
        XCTAssertEqual((error as NSError).code, StorageErrorCode.objectNotFound.rawValue)
      }
    }

    func testDeleteAfterPut() async throws {
      let ref = storage.reference(withPath: "ios/public/fileToDelete")
      let data = try XCTUnwrap("Hello Swift World".data(using: .utf8), "Data construction failed")
      let result = try await ref.putDataAsync(data)
      XCTAssertNotNil(result)
      let result2: Void = try await ref.delete()
      XCTAssertNotNil(result2)
    }

    func testSimplePutData() async throws {
      let ref = storage.reference(withPath: "ios/public/testBytesUpload")
      let data = try XCTUnwrap("Hello Swift World".data(using: .utf8), "Data construction failed")
      let result = try await ref.putDataAsync(data)
      XCTAssertNotNil(result)
    }

    func testSimplePutSpecialCharacter() async throws {
      let ref = storage.reference(withPath: "ios/public/-._~!$'()*,=:@&+;")
      let data = try XCTUnwrap("Hello Swift World-._~!$'()*,=:@&+;".data(using: .utf8),
                               "Data construction failed")
      let result = try await ref.putDataAsync(data)
      XCTAssertNotNil(result)
    }

    func testSimplePutDataInBackgroundQueue() async throws {
      actor Background {
        func uploadData(_ ref: StorageReference) async throws -> StorageMetadata {
          let data = try XCTUnwrap(
            "Hello Swift World".data(using: .utf8),
            "Data construction failed"
          )
          XCTAssertFalse(Thread.isMainThread)
          return try await ref.putDataAsync(data)
        }
      }
      let ref = storage.reference(withPath: "ios/public/testBytesUpload")
      let result = try await Background().uploadData(ref)
      XCTAssertNotNil(result)
    }

    func testSimplePutEmptyData() async throws {
      let ref = storage.reference(withPath: "ios/public/testSimplePutEmptyData")
      let data = Data()
      let result = try await ref.putDataAsync(data)
      XCTAssertNotNil(result)
    }

    func testSimplePutDataUnauthorized() async throws {
      let ref = storage.reference(withPath: "ios/private/secretfile.txt")
      let data = try XCTUnwrap("Hello Swift World".data(using: .utf8), "Data construction failed")
      do {
        _ = try await ref.putDataAsync(data)
        XCTFail("Unexpected success from unauthorized putData")
      } catch {
        XCTAssertEqual((error as NSError).code, StorageErrorCode.unauthorized.rawValue)
      }
    }

    // TODO: Update this function when the task handle APIs are updated for the new Swift Concurrency.
    func testSimplePutFile() throws {}

    func testAttemptToUploadDirectoryShouldFail() async throws {
      // This `.numbers` file is actually a directory.
      let fileName = "HomeImprovement.numbers"
      let bundle = Bundle(for: StorageIntegrationCommon.self)
      let fileURL = try XCTUnwrap(bundle.url(forResource: fileName, withExtension: ""),
                                  "Failed to get filePath")
      let ref = storage.reference(withPath: "ios/public/" + fileName)
      do {
        _ = try await ref.putFileAsync(from: fileURL)
        XCTFail("Unexpected success from putFile of a directory")
      } catch {
        // TODO: Investigate generating a more descriptive error code than unknown.
        let e = error as NSError
        XCTAssertEqual(e.code, StorageErrorCode.unknown.rawValue)
      }
    }

    func testPutFileWithSpecialCharacters() async throws {
      let fileName = "hello&+@_ .txt"
      let ref = storage.reference(withPath: "ios/public/" + fileName)
      let data = try XCTUnwrap("Hello Swift World".data(using: .utf8), "Data construction failed")
      let tmpDirURL = URL(fileURLWithPath: NSTemporaryDirectory())
      let fileURL = tmpDirURL.appendingPathComponent("hello.txt")
      try data.write(to: fileURL, options: .atomicWrite)
      let metadata = try await ref.putFileAsync(from: fileURL)
      XCTAssertEqual(fileName, metadata.name)
      let result = try await ref.getMetadata()
      XCTAssertNotNil(result)
    }

    func testSimplePutDataNoMetadata() async throws {
      let ref = storage.reference(withPath: "ios/public/testSimplePutDataNoMetadata")
      let data = try XCTUnwrap("Hello Swift World".data(using: .utf8), "Data construction failed")
      let result = try await ref.putDataAsync(data)
      XCTAssertNotNil(result)
    }

    func testSimplePutFileNoMetadata() async throws {
      let fileName = "hello&+@_ .txt"
      let ref = storage.reference(withPath: "ios/public/" + fileName)
      let data = try XCTUnwrap("Hello Swift World".data(using: .utf8), "Data construction failed")
      let tmpDirURL = URL(fileURLWithPath: NSTemporaryDirectory())
      let fileURL = tmpDirURL.appendingPathComponent("hello.txt")
      try data.write(to: fileURL, options: .atomicWrite)
      let result = try await ref.putFileAsync(from: fileURL)
      XCTAssertNotNil(result)
    }

    func testSimpleGetData() async throws {
      let ref = storage.reference(withPath: "ios/public/1mb2")
      let result = try await ref.data(maxSize: 1024 * 1024)
      XCTAssertNotNil(result)
    }

    func testSimpleGetDataWithTask() async throws {
      let ref = storage.reference(withPath: "ios/public/1mb2")
      let result = try await ref.data(maxSize: 1024 * 1024)
      XCTAssertNotNil(result)
    }

    func testSimpleGetDataInBackgroundQueue() async throws {
      actor Background {
        func data(from ref: StorageReference) async throws -> Data {
          XCTAssertFalse(Thread.isMainThread)
          return try await ref.data(maxSize: 1024 * 1024)
        }
      }
      let ref = storage.reference(withPath: "ios/public/1mb2")
      let result = try await Background().data(from: ref)
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
      let range = NSRange(location: 0, length: urlString.count)
      XCTAssertNotNil(testRegex.firstMatch(in: urlString, options: [], range: range))
    }

    func testAsyncWrite() async throws {
      let ref = storage.reference(withPath: "ios/public/helloworld")
      let tmpDirURL = URL(fileURLWithPath: NSTemporaryDirectory())
      let fileURL = tmpDirURL.appendingPathComponent("hello.txt")
      let data = try XCTUnwrap("Hello Swift World".data(using: .utf8), "Data construction failed")

      _ = try await ref.putDataAsync(data)
      let url = try await ref.writeAsync(toFile: fileURL)
      XCTAssertEqual(url.lastPathComponent, "hello.txt")
    }

    func testSimpleGetFile() throws {
      let expectation = self.expectation(description: #function)
      let ref = storage.reference(withPath: "ios/public/helloworld")
      let tmpDirURL = URL(fileURLWithPath: NSTemporaryDirectory())
      let fileURL = tmpDirURL.appendingPathComponent("hello.txt")
      let data = try XCTUnwrap("Hello Swift World".data(using: .utf8), "Data construction failed")

      Task {
        _ = try await ref.putDataAsync(data)
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
      let pageToken = try XCTUnwrap(listResult.pageToken)
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
      let kTestTimeout = 60.0
      waitForExpectations(timeout: kTestTimeout,
                          handler: { error in
                            if let error = error {
                              print(error)
                            }
                          })
    }
  }
#endif
