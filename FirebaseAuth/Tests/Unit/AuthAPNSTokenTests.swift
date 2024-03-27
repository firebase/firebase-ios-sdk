// Copyright 2023 Google LLC
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

#if !os(macOS)
  import Foundation
  import XCTest

  @testable import FirebaseAuth

  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  class AuthAPNSTokenTests: XCTestCase {
    /** @fn testProperties
        @brief Tests the properties of the class.
     */
    func testProperties() throws {
      let data = try XCTUnwrap("asdf".data(using: .utf8))
      let token = AuthAPNSToken(withData: data, type: .prod)
      XCTAssertEqual(token.data, data)
      XCTAssertEqual(token.string, "61736466") // hex string representation of "asdf"
      XCTAssertEqual(token.type, .prod)
    }
  }
#endif
