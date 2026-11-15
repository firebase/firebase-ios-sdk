// Copyright 2026 Google LLC
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

import CryptoKit
import FirebaseStorage
import Security
import XCTest

/// Large uploads and downloads, and transfers that are paused, resumed, and cancelled as they
/// run. Each test uploads objects with names of their own, and deletes them when it ends.
class StorageTransferSoakTests: StorageIntegrationCommon {
  /// More than the 10 MB that an upload of data sends per request, so that the upload takes
  /// three requests. The odd size makes the last one partial.
  private static let largeSize = 24 * 1024 * 1024 + 12345

  /// The chunk size of the uploads that are paused, resumed, and cancelled between chunks.
  private static let chunkSize: Int64 = 256 * 1024

  private static let timeout: TimeInterval = 300

  private var uploadedReferences: [StorageReference] = []

  override func tearDown() {
    // The tests share the Storage instance.
    storage.uploadChunkSizeBytes = Int64.max
    let deletions = uploadedReferences.map { ref in
      let deletion = expectation(description: "delete \(ref.fullPath)")
      ref.delete { _ in deletion.fulfill() }
      return deletion
    }
    wait(for: deletions, timeout: 60)
    super.tearDown()
  }

  /// An upload of data larger than a chunk takes several requests, and the object gets every
  /// byte.
  func testLargeDataUploadsInSeveralChunks() {
    let data = Self.randomData(count: Self.largeSize)
    let ref = newReference()
    let uploaded = expectation(description: "uploaded")
    var completedBytes: Int64 = -1
    let task = ref.putData(data) { result in
      self.assertObject(result, matches: data)
      uploaded.fulfill()
    }
    task.observe(.progress) { snapshot in
      let completed = snapshot.progress?.completedUnitCount ?? -1
      XCTAssertGreaterThanOrEqual(completed, completedBytes)
      completedBytes = completed
    }
    wait(for: [uploaded], timeout: Self.timeout)
  }

  /// An upload of a file in small chunks sends each chunk, and the object gets every byte.
  func testFileUploadsInSmallChunks() throws {
    let data = Self.randomData(count: 3 * 1024 * 1024 + 1000)
    let fileURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("StorageTransferSoakTests-\(UUID().uuidString)")
    try data.write(to: fileURL)
    defer { try? FileManager.default.removeItem(at: fileURL) }
    storage.uploadChunkSizeBytes = Self.chunkSize
    let ref = newReference()
    let uploaded = expectation(description: "uploaded")
    var completedBytes: Int64 = -1
    var progressCount = 0
    let task = ref.putFile(from: fileURL) { result in
      self.assertObject(result, matches: data)
      uploaded.fulfill()
    }
    task.observe(.progress) { snapshot in
      let completed = snapshot.progress?.completedUnitCount ?? -1
      XCTAssertGreaterThanOrEqual(completed, completedBytes)
      completedBytes = completed
      progressCount += 1
    }
    wait(for: [uploaded], timeout: Self.timeout)
    // Each chunk reports progress at least once.
    XCTAssertGreaterThanOrEqual(progressCount, data.count / Int(Self.chunkSize))
  }

  /// An upload that is paused between chunks several times continues from the bytes that the
  /// server has received, and the object gets every byte.
  func testPausedUploadContinuesWhereItStopped() {
    let data = Self.randomData(count: 8 * 1024 * 1024)
    storage.uploadChunkSizeBytes = Self.chunkSize
    let ref = newReference()
    let uploaded = expectation(description: "uploaded")
    var pausePoints: [Int64] = [1, 3, 5].map { $0 * 1024 * 1024 }
    var pausedAt: Int64 = 0
    var resumedAfter: Int64?
    var pauseCount = 0
    var resumeCount = 0
    let task = ref.putData(data) { result in
      self.assertObject(result, matches: data)
      uploaded.fulfill()
    }
    task.observe(.progress) { snapshot in
      let completed = snapshot.progress?.completedUnitCount ?? 0
      if let resumedAfter {
        // The server has received every chunk before the one that was sending, so the upload
        // continues at most a chunk, rounded to the server's granularity, before the pause.
        XCTAssertGreaterThan(completed, resumedAfter - 2 * Self.chunkSize)
      }
      resumedAfter = nil
      if let pausePoint = pausePoints.first, completed > pausePoint {
        pausePoints.removeFirst()
        pausedAt = completed
        task.pause()
      }
    }
    task.observe(.pause) { _ in
      pauseCount += 1
      task.resume()
    }
    task.observe(.resume) { _ in
      // Every later progress event is from the resumed transfer.
      resumeCount += 1
      resumedAfter = pausedAt
    }
    wait(for: [uploaded], timeout: Self.timeout)
    XCTAssertEqual(pauseCount, 3)
    XCTAssertEqual(resumeCount, 3)
  }

  /// An upload that is cancelled between chunks fails with `StorageErrorCode.cancelled`, and
  /// leaves no object.
  func testCancelledUploadLeavesNoObject() {
    let data = Self.randomData(count: 8 * 1024 * 1024)
    storage.uploadChunkSizeBytes = Self.chunkSize
    let ref = newReference()
    let failed = expectation(description: "failed")
    let task = ref.putData(data) { result in
      switch result {
      case .success:
        XCTFail("Unexpected success of a cancelled upload")
      case let .failure(error):
        XCTAssertEqual((error as NSError).code, StorageErrorCode.cancelled.rawValue)
      }
      failed.fulfill()
    }
    task.observe(.progress) { snapshot in
      if (snapshot.progress?.completedUnitCount ?? 0) > 1024 * 1024 {
        task.cancel()
      }
    }
    wait(for: [failed], timeout: Self.timeout)

    let checked = expectation(description: "checked")
    ref.getMetadata { result in
      switch result {
      case .success:
        XCTFail("A cancelled upload left an object")
      case let .failure(error):
        XCTAssertEqual((error as NSError).code, StorageErrorCode.objectNotFound.rawValue)
      }
      checked.fulfill()
    }
    wait(for: [checked], timeout: Self.timeout)
  }

  /// A download to a file that is paused and resumed several times writes every byte.
  func testPausedDownloadToFileWritesEveryByte() throws {
    let data = Self.randomData(count: 16 * 1024 * 1024)
    let ref = uploadedObject(with: data)
    let fileURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("StorageTransferSoakTests-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: fileURL) }

    let downloaded = expectation(description: "downloaded")
    var pausePoints: [Int64] = [1, 3, 5].map { $0 * 1024 * 1024 }
    var pauseCount = 0
    let task = ref.write(toFile: fileURL)
    task.observe(.progress) { snapshot in
      if let pausePoint = pausePoints.first,
         (snapshot.progress?.completedUnitCount ?? 0) > pausePoint {
        pausePoints.removeFirst()
        task.pause()
      }
    }
    task.observe(.pause) { _ in
      pauseCount += 1
      task.resume()
    }
    task.observe(.success) { _ in
      downloaded.fulfill()
    }
    task.observe(.failure) { snapshot in
      XCTFail("Unexpected error \(String(describing: snapshot.error))")
      downloaded.fulfill()
    }
    wait(for: [downloaded], timeout: Self.timeout)
    XCTAssertEqual(try Data(contentsOf: fileURL), data)
    // A download that finishes before a pause takes effect succeeds without pausing.
    XCTAssertGreaterThan(pauseCount, 0)
  }

  // MARK: - Helpers

  /// Returns a reference to an object with a name of its own, which `tearDown()` deletes.
  private func newReference() -> StorageReference {
    let ref = storage.reference(withPath: "ios/public/StorageTransferSoakTests/\(UUID())")
    uploadedReferences.append(ref)
    return ref
  }

  /// Uploads `data` to a new object, and returns its reference.
  private func uploadedObject(with data: Data) -> StorageReference {
    let ref = newReference()
    let uploaded = expectation(description: "uploaded")
    ref.putData(data) { result in
      self.assertObject(result, matches: data)
      uploaded.fulfill()
    }
    wait(for: [uploaded], timeout: Self.timeout)
    return ref
  }

  /// Asserts that an upload succeeded, and that the object has the bytes of `data`.
  private func assertObject(_ result: Result<StorageMetadata, Error>, matches data: Data,
                            file: StaticString = #filePath, line: UInt = #line) {
    switch result {
    case let .success(metadata):
      XCTAssertEqual(metadata.size, Int64(data.count), file: file, line: line)
      XCTAssertEqual(metadata.md5Hash, Data(Insecure.MD5.hash(data: data)).base64EncodedString(),
                     file: file, line: line)
    case let .failure(error):
      XCTFail("Unexpected error \(error)", file: file, line: line)
    }
  }

  /// Returns `count` random bytes, so that bytes at the wrong offset change the object.
  private static func randomData(count: Int) -> Data {
    var data = Data(count: count)
    let status = data.withUnsafeMutableBytes { buffer in
      SecRandomCopyBytes(kSecRandomDefault, count, buffer.baseAddress!)
    }
    precondition(status == errSecSuccess, "SecRandomCopyBytes failed with \(status)")
    return data
  }
}
