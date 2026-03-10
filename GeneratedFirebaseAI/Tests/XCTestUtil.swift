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

import XCTest

extension XCTestCase {
  func XCTAssertEqualAndSameType<T: Equatable>(_ lhs: Any?, _ rhs: T?,
                                               file: StaticString = #filePath, line: UInt = #line) {
    if lhs == nil, rhs == nil {
      return
    }

    guard let lhs = lhs as? T else {
      XCTFail("Expected the type \"\(T.self)\" but found \(String(describing: lhs))")
      return
    }

    XCTAssertEqual(lhs, rhs, file: file, line: line)
  }

  func WrongType<T>(for: T.Type, _ value: Any?) {
    XCTFail("Expected the type \"\(T.self)\" but found \(String(describing: value))")
  }
}
