import XCTest
import Foundation
@testable import sem_versions

final class PackageReaderTests: XCTestCase {
    func testSimpleValidPod() {
      let rootDirURL = URL(fileURLWithPath: "/Users/mmaksym/Projects/firebase-ios-sdk2/ZipBuilder/TestResources/CocoapodsReaderSamples/CocoapodsReader/SimpleValidPod")
      print("rootDirURL: \(rootDirURL.absoluteString)")

      let cocoapodsReader = CocoapodsReader()

      do {
        let packages = try cocoapodsReader.packagesInDirectory(rootDirURL)
        XCTAssertEqual(packages.count, 1)
        guard let package = packages.first else {
          XCTFail()
          return
        }

        XCTAssertEqual(package.name, "FirebaseCore")

      } catch {
        XCTFail("Error: \(error)")
      }
    }

    static var allTests = [
        ("testSimpleValidPod", testSimpleValidPod),
    ]
}
