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

@available(iOS 13.0, macOS 10.15, macCatalyst 13.0, tvOS 13.0, watchOS 6.0, *)
class StoragePOSIXErrorTest: StorageIntegrationCommon {
  func testPutFileWithPOSIXError40() async throws {
    let ref = storage.reference(withPath: "ios/public/testPOSIX40")

    let data = try XCTUnwrap("Hello".data(using: .utf8))
    let tmpDirURL = URL(fileURLWithPath: NSTemporaryDirectory())
    let fileURL = tmpDirURL.appendingPathComponent(#function + "hello.txt")
    try data.write(to: fileURL, options: .atomicWrite)
    defer {
      try? FileManager.default.removeItem(at: fileURL)
    }

    do {
      let metadata = try await ref.putFileAsync(from: fileURL)
      XCTAssertEqual(metadata.size, Int64(data.count))
    } catch {
      XCTFail("Unexpected failure: \(error)")
    }
  }
}
