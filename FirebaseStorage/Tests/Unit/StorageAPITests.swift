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

// MARK: This file is used to evaluate the experience of using Firebase APIs in Swift.

import Foundation
import XCTest

import FirebaseCore
import FirebaseStorage

final class StorageAPITests: XCTestCase {
  func StorageAPIs() {
    let app = FirebaseApp.app()
    _ = Storage.storage()
    _ = Storage.storage(app: app!)
    _ = Storage.storage(url: "my-url")
    let storage = Storage.storage(app: app!, url: "my-url")
    _ = storage.app
    storage.maxUploadRetryTime = storage.maxUploadRetryTime + 1
    storage.maxDownloadRetryTime = storage.maxDownloadRetryTime + 1
    storage.maxOperationRetryTime = storage.maxOperationRetryTime + 1
    let queue: DispatchQueue = storage.callbackQueue
    storage.callbackQueue = queue
    _ = storage.reference()
    _ = storage.reference(forURL: "my-url")
    _ = storage.reference(withPath: "path")
    storage.useEmulator(withHost: "host", port: 123)
  }

  func StorageReferenceApis() {
    var ref = Storage.storage().reference()
    _ = ref.storage
    _ = ref.bucket
    _ = ref.fullPath
    _ = ref.name

    ref = ref.root()
    ref = ref.parent()!
    ref = ref.child("path")

    let metadata = StorageMetadata()

    _ = ref.putData(Data())
    _ = ref.putData(Data(), metadata: metadata)
    _ = ref.putData(Data(), metadata: metadata) { (result: Result<StorageMetadata, Error>) in
    }
    _ = ref.putData(Data(), metadata: metadata) { (result: StorageMetadata?, error: Error?) in
    }

    let file = URL(string: "my-url")!
    _ = ref.putFile(from: file)
    _ = ref.putFile(from: file, metadata: metadata)
    _ = ref.putFile(from: file, metadata: metadata) { (result: Result<StorageMetadata, Error>) in
    }
    _ = ref.putFile(from: file, metadata: metadata) { (result: StorageMetadata?, error: Error?) in
    }

    _ = ref.getData(maxSize: 122) { (result: Data?, error: Error?) in
    }
    _ = ref.getData(maxSize: 122) { (result: Result<Data, Error>) in
    }

    ref.downloadURL { (result: URL?, error: Error?) in
    }
    ref.downloadURL { (result: Result<URL, Error>) in
    }

    ref.write(toFile: file)
    ref.write(toFile: file) { (result: URL?, error: Error?) in
    }
    ref.write(toFile: file) { (result: Result<URL, Error>) in
    }

    ref.listAll { (listResult: StorageListResult?, error: Error?) in
    }
    ref.listAll { (result: Result<StorageListResult, Error>) in
    }

    ref.list(maxResults: 123) { (listResult: StorageListResult?, error: Error?) in
    }
    ref.list(maxResults: 222) { (result: Result<StorageListResult, Error>) in
    }
    ref
      .list(maxResults: 123,
            pageToken: "pageToken") { (listResult: StorageListResult?, error: Error?) in
      }
    ref
      .list(maxResults: 222, pageToken: "pageToken") { (result: Result<StorageListResult, Error>) in
      }

    ref.getMetadata { (result: Result<StorageMetadata, Error>) in
    }
    ref.getMetadata { (result: StorageMetadata?, error: Error?) in
    }

    ref.delete { (error: Error?) in
    }
  }

  #if Firebase9Breaking
    func StorageConstantsTypedefs() {
      var _: StorageHandle
      var _: StorageVoidDataError
      var _: StorageVoidError
      var _: StorageVoidMetadata
      var _: StorageVoidMetadataError
      var _: StorageVoidSnapshot
      var _: StorageVoidURLError
    }
  #endif

  func testStorageConstantsGlobal() {
    XCTAssertEqual(StorageErrorDomain, "FIRStorageErrorDomain")
  }

  func StorageListResultApis(result: StorageListResult) {
    _ = result.prefixes
    _ = result.items
    _ = result.pageToken
  }

  func taskStatuses(status: StorageTaskStatus) -> StorageTaskStatus {
    switch status {
    case .unknown: return status
    case .resume: return status
    case .progress: return status
    case .pause: return status
    case .success: return status
    case .failure: return status
    @unknown default:
      fatalError()
    }
  }

  func errorCodes(code: StorageErrorCode) -> StorageErrorCode {
    switch code {
    case .unknown: return code
    case .objectNotFound: return code
    case .bucketNotFound: return code
    case .projectNotFound: return code
    case .quotaExceeded: return code
    case .unauthenticated: return code
    case .unauthorized: return code
    case .retryLimitExceeded: return code
    case .nonMatchingChecksum: return code
    case .downloadSizeExceeded: return code
    case .cancelled: return code
    case .invalidArgument: return code
    @unknown default:
      fatalError()
    }
  }

  func storageMetadataApis() {
    let metadata = StorageMetadata()
    _ = metadata.bucket
    _ = metadata.cacheControl
    _ = metadata.contentDisposition
    _ = metadata.contentEncoding
    _ = metadata.contentLanguage
    _ = metadata.contentType
    _ = metadata.md5Hash
    _ = metadata.generation
    _ = metadata.customMetadata
    _ = metadata.metageneration
    _ = metadata.name
    _ = metadata.path
    _ = metadata.size
    _ = metadata.timeCreated
    _ = metadata.updated
    _ = metadata.dictionaryRepresentation()
    _ = metadata.isFile
    _ = metadata.isFolder
  }

  func StorageObservableTaskApis(ref: StorageReference) throws {
    let task = ref.write(toFile: URL(string: "url")!)
    _ = task.observe(.pause) { snaphot in
    }
    task.removeObserver(withHandle: "handle")
    task.removeAllObservers()
    task.removeAllObservers(for: .progress)
  }

  func StorageTaskApis(task: StorageTask) {
    _ = task.snapshot
  }

  func StorageTaskManagementApis(task: StorageTaskManagement) {
    task.enqueue()
    task.pause?()
    task.cancel?()
    task.resume?()
  }

  func StorageTaskSnapshotApis(snapshot: StorageTaskSnapshot) {
    _ = snapshot.task
    _ = snapshot.metadata
    _ = snapshot.reference
    _ = snapshot.progress
    _ = snapshot.error
    _ = snapshot.status
  }
}
