/*
 * Copyright 2020 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import XCTest
import Foundation
@testable import sem_versions

final class PackageReaderTests: XCTestCase {
  func testSimpleValidPod() {
    //
    let rootDirURL =
      URL(fileURLWithPath: "/Users/mmaksym/Projects/firebase-ios-sdk2/ZipBuilder/TestResources/CocoaPodsReaderSamples/CocoaPodsReader/SimpleValidPod/")
    print("rootDirURL: \(rootDirURL.absoluteString)")

    let cocoaPodsReader = CocoaPodsReader()

    do {
      let packages = try cocoaPodsReader.packagesInDirectory(rootDirURL)
      XCTAssertEqual(packages.count, 1)
      guard let package = packages.first else {
        XCTFail()
        return
      }

      XCTAssertEqual(package.name, "FirebaseCore")
      XCTAssertEqual(package.version, "6.6.6")

      XCTAssertEqual(package.publicHeaderPaths.count, 1)
      XCTAssertEqual(package.sourceFilePaths.count, 5)

      XCTAssert(package.publicHeaderPaths.contains("FirebaseCore/Sources/Public/FIRApp.h"))

    } catch {
      XCTFail("Error: \(error)")
    }
  }

  static var allTests = [
    ("testSimpleValidPod", testSimpleValidPod),
  ]
}
