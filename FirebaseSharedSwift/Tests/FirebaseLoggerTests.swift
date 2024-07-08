// Copyright 2024 Google LLC
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

import FirebaseSharedSwift
import Foundation

// MARK: - Test Suite

import XCTest

extension FirebaseProduct {
  static let test = FirebaseProduct(name: "test")
}

extension FirebaseLogger {
  static let testLogger = FirebaseLogger(firebaseProduct: FirebaseProduct.test)
}

class TestFirebaseLogger: XCTestCase {
  func testLoggerUsage() {
    FirebaseLogger.testLogger.debug("Set up successfully!")
  }
}
