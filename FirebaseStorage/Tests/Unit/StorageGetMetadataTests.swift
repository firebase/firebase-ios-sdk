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

import FirebaseCoreInternal
@testable import FirebaseStorage
import Foundation
import XCTest

class StorageGetMetadataTests: StorageTestHelpers {
  func testFetcherConfiguration() async {
    let testBlock = StorageTestTransport { request in
      XCTAssertEqual(request.url, self.objectURL())
      XCTAssertEqual(request.httpMethod, "GET")
      return try (Data(), StorageTestTransport.response(to: request, statusCode: 200))
    }
    await StorageHTTPService.shared.updateTestTransport(testBlock)
    let ref = storage().reference(withPath: "object")
    do {
      let _ = try await ref.getMetadata()
    } catch {
      // All testing is in test block.
    }
  }

  func testSuccessfulFetch() async {
    await StorageHTTPService.shared.updateTestTransport(successBlock())
    let ref = storage().reference(withPath: "object")
    do {
      let _ = try await ref.getMetadata()
    } catch {
      // All testing is in test block.
    }
  }

  func testSuccessfulFetchWithEmulator() async {
    let storage = self.storage()
    storage.useEmulator(withHost: "localhost", port: 8080)

    let testBlock = successBlock(
      withURL: URL(string: "http://localhost:8080/v0/b/bucket/o/object")!
    )
    await StorageHTTPService.shared.updateTestTransport(testBlock)
    let ref = storage.reference(withPath: "object")
    do {
      let _ = try await ref.getMetadata()
    } catch {
      // All testing is in test block.
    }
  }

  func testUnsuccessfulFetchUnauthenticated() async {
    let storage = storage()
    await StorageHTTPService.shared.updateTestTransport(unauthenticatedBlock())
    let path = objectPath()
    let ref = StorageReference(storage: storage, path: path)
    do {
      let _ = try await ref.getMetadata()
    } catch {
      XCTAssertEqual((error as NSError).code, StorageErrorCode.unauthenticated.rawValue)
    }
  }

  func testUnsuccessfulFetchUnauthorized() async {
    let storage = storage()
    await StorageHTTPService.shared.updateTestTransport(unauthorizedBlock())
    let path = objectPath()
    let ref = StorageReference(storage: storage, path: path)
    do {
      let _ = try await ref.getMetadata()
    } catch {
      XCTAssertEqual((error as NSError).code, StorageErrorCode.unauthorized.rawValue)
    }
  }

  func testUnsuccessfulFetchObjectDoesntExist() async {
    let storage = storage()
    await StorageHTTPService.shared.updateTestTransport(notFoundBlock())
    let path = objectPath()
    let ref = StorageReference(storage: storage, path: path)
    do {
      let _ = try await ref.getMetadata()
    } catch {
      XCTAssertEqual((error as NSError).code, StorageErrorCode.objectNotFound.rawValue)
    }
  }

  func testUnsuccessfulFetchBadJSON() async {
    await StorageHTTPService.shared.updateTestTransport(invalidJSONBlock())
    let path = objectPath()
    let ref = StorageReference(storage: storage(), path: path)
    do {
      let _ = try await ref.getMetadata()
    } catch {
      XCTAssertEqual((error as NSError).code, StorageErrorCode.unknown.rawValue)
    }
  }
}
