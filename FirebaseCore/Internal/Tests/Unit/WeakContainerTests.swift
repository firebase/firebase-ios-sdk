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

@testable import FirebaseCoreInternal
import XCTest

class WeakContainerTests: XCTestCase {
  func testContainersObjectIsWeaklyRetained() throws {
    // Given
    var object: AnyObject? = NSObject()
    let weakObject = WeakContainer(object: object)
    XCTAssertNotNil(weakObject.object)
    // When
    object = nil
    // Then
    XCTAssertNil(weakObject.object)
  }
}
