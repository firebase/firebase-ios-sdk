// Copyright 2022 Google LLC
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
import XCTest

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class StorageApiV2Tests: StorageIntegrationCommon {
  func testDeleteWithNilCompletion() async throws {
    let ref = storage.reference(withPath: "ios/public/fileToDelete")
    let data = try XCTUnwrap("Hello Swift World".data(using: .utf8), "Data construction failed")
    try await ref.putDataV2(data)
    ref.delete(completion: nil)
  }

  func testSimplePutData() async throws {
    let ref = storage.reference(withPath: "ios/public/testBytesUpload")
    let data = try XCTUnwrap("Hello Swift World".data(using: .utf8), "Data construction failed")
    let metadata = try await ref.putDataV2(data)
    XCTAssertEqual(metadata.name, "testBytesUpload")
  }

  func testSimplePutSpecialCharacter() async throws {
    let ref = storage.reference(withPath: "ios/public/-._~!$'()*,=:@&+;")
    let data = try XCTUnwrap("Hello Swift World".data(using: .utf8), "Data construction failed")
    let metadata = try await ref.putDataV2(data)
    XCTAssertEqual(metadata.name, "-._~!$'()*,=:@&+;")
  }

  func testSimplePutDataInBackgroundQueue() async throws {
    let ref = storage.reference(withPath: "ios/public/testBytesUpload")
    let data = try XCTUnwrap("Hello Swift World".data(using: .utf8), "Data construction failed")
    let workerTask = Task {
      try await ref.putDataV2(data)
    }
    let metadata = try await workerTask.value
    XCTAssertEqual(metadata.name, "testBytesUpload")
  }

  func testSimplePutEmptyData() async throws {
    let ref = storage.reference(withPath: "ios/public/testSimplePutEmptyData")
    let data = Data()
    let metadata = try await ref.putDataV2(data)
    XCTAssertEqual(metadata.name, "testSimplePutEmptyData")
  }

  func testSimplePutDataUnauthorized() async throws {
    let file = "ios/private/secretfile.txt"
    let ref = storage.reference(withPath: file)
    let data = try XCTUnwrap("Hello Swift World".data(using: .utf8), "Data construction failed")
    do {
      try await ref.putDataV2(data)
    } catch {
      let error = try XCTUnwrap(error as? StorageError)
      switch error {
      case let .unauthorized(bucket, object):
        XCTAssertEqual(bucket, "ios-opensource-samples.appspot.com")
        XCTAssertEqual(object, file)
      default:
        XCTFail("Failed with unexpected error: \(error)")
      }
      return
    }
    XCTFail("Unexpected success from unauthorized putData")
  }

  func testSimplePutFileWithProgressBlock() async throws {
    let ref = storage.reference(withPath: "ios/public/testSimplePutFile")
    let data = try XCTUnwrap("Hello Swift World".data(using: .utf8), "Data construction failed")
    let tmpDirURL = URL(fileURLWithPath: NSTemporaryDirectory())
    let fileURL = tmpDirURL.appendingPathComponent("hello.txt")
    try data.write(to: fileURL, options: .atomicWrite)

    var uploadedBytes: Int64 = -1
    var progressFulfilled = false
    let progressBlock = { (progress: Progress) in
      XCTAssertGreaterThanOrEqual(progress.completedUnitCount, uploadedBytes)
      uploadedBytes = progress.completedUnitCount
      if !progressFulfilled {
        progressFulfilled = true
      }
    }

    let metadata = try await ref.putFileV2(from: fileURL, progressBlock: progressBlock)
    XCTAssertEqual(metadata.name, "testSimplePutFile")
    XCTAssertTrue(progressFulfilled)
  }

  func testSimplePutFileWithProgressBlockAndProgress() async throws {
    let ref = storage.reference(withPath: "ios/public/testSimplePutFile")
    let data = try XCTUnwrap("Hello Swift World".data(using: .utf8), "Data construction failed")
    let tmpDirURL = URL(fileURLWithPath: NSTemporaryDirectory())
    let fileURL = tmpDirURL.appendingPathComponent("hello.txt")
    try data.write(to: fileURL, options: .atomicWrite)

    let outerProgress = Progress()
    var uploadedBytes: Int64 = -1
    var progressFulfilled = false
    let progressBlock = { (progress: Progress) in
      // Verify passed in progress is used for return value.
      XCTAssertEqual(progress, outerProgress)
      XCTAssertGreaterThanOrEqual(progress.completedUnitCount, uploadedBytes)
      uploadedBytes = progress.completedUnitCount
      if !progressFulfilled {
        progressFulfilled = true
      }
    }

    let metadata = try await ref.putFileV2(from: fileURL, progress: outerProgress,
                                           progressBlock: progressBlock)
    XCTAssertEqual(metadata.name, "testSimplePutFile")
    XCTAssertTrue(progressFulfilled)
    XCTAssertTrue(outerProgress.isFinished)
  }

  func testSimplePutFileWithCancel() async throws {
    let ref = storage.reference(withPath: "ios/public/1mb2")
    let data = try await ref.data(maxSize: 1024 * 1024)
    let tmpDirURL = URL(fileURLWithPath: NSTemporaryDirectory())
    let fileURL = tmpDirURL.appendingPathComponent("hello.txt")
    try data.write(to: fileURL, options: .atomicWrite)

    let progress = Progress()
    let workerTask = Task {
      try await ref.putFileV2(from: fileURL, progress: progress)
    }
    XCTAssertFalse(progress.isCancelled)
    progress.cancel()
    XCTAssertTrue(progress.isCancelled)

    do {
      _ = try await workerTask.value
    } catch {
      let storageError = try! XCTUnwrap(error as? StorageError)
      switch storageError {
      case .cancelled: XCTAssertTrue(true)
      default: XCTFail("Unexpected error")
      }
      return
    }
    XCTFail("Failed to cancel")
  }

  func testSimplePutFileWithCancelFromProgress() async throws {
    let ref = storage.reference(withPath: "ios/public/testSimplePutFile")
    let data = try XCTUnwrap("Hello Swift World".data(using: .utf8), "Data construction failed")
    let tmpDirURL = URL(fileURLWithPath: NSTemporaryDirectory())
    let fileURL = tmpDirURL.appendingPathComponent("hello.txt")
    try data.write(to: fileURL, options: .atomicWrite)

    let progress = Progress()
    var uploadedBytes: Int64 = -1
    var progressFulfilled = false
    let progressBlock = { (progress: Progress) in
      XCTAssertGreaterThanOrEqual(progress.completedUnitCount, uploadedBytes)
      uploadedBytes = progress.completedUnitCount
      if !progressFulfilled {
        progressFulfilled = true
        progress.cancel()
      }
    }
    do {
      _ = try await ref.putFileV2(from: fileURL, progress: progress, progressBlock: progressBlock)
    } catch {
      XCTAssertEqual("cancelled", "\(error)")
      XCTAssertTrue(progressFulfilled)
      return
    }
    XCTFail("Failed to cancel")
  }

  func testAttemptToUploadDirectoryShouldFail() async throws {
    // This `.numbers` file is actually a directory.
    let fileName = "HomeImprovement.numbers"
    let bundle = Bundle(for: StorageIntegrationCommon.self)
    let fileURL = try XCTUnwrap(bundle.url(forResource: fileName, withExtension: ""),
                                "Failed to get filePath")
    let ref = storage.reference(withPath: "ios/public/" + fileName)
    do {
      try await ref.putFileV2(from: fileURL)
    } catch {
      let error = try XCTUnwrap(error as? StorageError)
      switch error {
      case let .unknown(message):
        print(message)
        XCTAssertTrue(message.hasSuffix("is not reachable. Ensure file URL is not a directory, " +
            "symbolic link, or invalid url."))
      default:
        XCTFail("Failed with unexpected error: \(error)")
      }
      return
    }
    XCTFail("Unexpected success from unauthorized putData")
  }

  func testPutFileWithSpecialCharacters() async throws {
    let fileName = "hello&+@_ .txt"
    let ref = storage.reference(withPath: "ios/public/" + fileName)
    let data = try XCTUnwrap("Hello Swift World".data(using: .utf8), "Data construction failed")
    let tmpDirURL = URL(fileURLWithPath: NSTemporaryDirectory())
    let fileURL = tmpDirURL.appendingPathComponent("hello.txt")
    try data.write(to: fileURL, options: .atomicWrite)

    let metadata = try await ref.putFileV2(from: fileURL)
    XCTAssertEqual(fileName, metadata.name)
    let metadataRef = try await ref.getMetadata()
    XCTAssertEqual(fileName, metadataRef.name)
  }
}
