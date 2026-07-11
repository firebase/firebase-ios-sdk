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

@testable import FirebaseStorage
import Foundation
#if COCOAPODS
  import GTMSessionFetcher
#else
  import GTMSessionFetcherCore
#endif
import XCTest

class StoragePutFileTests: StorageTestHelpers {
  func testPutFileWithPOSIXError40UpdatesExistingFetcherService() async throws {
    // Initialize storage *before* setting the testBlock to verify that
    // `StorageFetcherService.updateTestBlock` correctly updates pre-existing instances.
    let storageInstance = storage()
    let ref = storageInstance.reference(withPath: "ios/public/testPOSIX40")

    let testBlock: GTMSessionFetcherTestBlock = { fetcher, response in
      let error = NSError(domain: NSPOSIXErrorDomain, code: 40, userInfo: nil)
      response(nil, nil, error)
    }
    await StorageFetcherService.shared.updateTestBlock(testBlock)
    addTeardownBlock {
      await StorageFetcherService.shared.updateTestBlock(nil)
    }

    let data = try XCTUnwrap("Hello".data(using: .utf8))
    let tmpDirURL = URL(fileURLWithPath: NSTemporaryDirectory())
    let fileURL = tmpDirURL.appendingPathComponent(#function + "hello.txt")
    try data.write(to: fileURL, options: .atomicWrite)
    defer {
      try? FileManager.default.removeItem(at: fileURL)
    }

    do {
      _ = try await ref.putFileAsync(from: fileURL)
      XCTFail("Unexpected success")
    } catch let error as NSError {
      XCTAssertEqual(error.domain, StorageErrorDomain)
      XCTAssertEqual(error.code, StorageErrorCode.unknown.rawValue)
      let message = error.localizedDescription
      XCTAssertTrue(message.contains("POSIX errno 40 (Message too long)"),
                    "Error message should contain 'POSIX errno 40 (Message too long)', but got \(message)")
    }
  }
}
