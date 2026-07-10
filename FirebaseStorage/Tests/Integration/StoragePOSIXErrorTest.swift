import Foundation
@testable import FirebaseStorage
import GTMSessionFetcherCore
import XCTest

@available(iOS 13.0, macOS 10.15, macCatalyst 13.0, tvOS 13.0, watchOS 6.0, *)
class StoragePOSIXErrorTest: StorageIntegrationCommon {
  func testPutFileWithPOSIXError40() async throws {
    let ref = storage.reference(withPath: "ios/public/testPOSIX40")
    
    let data = try XCTUnwrap("Hello".data(using: .utf8))
    let tmpDirURL = URL(fileURLWithPath: NSTemporaryDirectory())
    let fileURL = tmpDirURL.appendingPathComponent(#function + "hello.txt")
    try data.write(to: fileURL, options: .atomicWrite)
    
    do {
      let metadata = try await ref.putFileAsync(from: fileURL)
      XCTAssertEqual(metadata.size, Int64(data.count))
    } catch {
      XCTFail("Unexpected failure: \(error)")
    }
  }
}
