// Copyright 2025 Google LLC
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

@testable import FirebaseVertexAI

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
final class APIVersionTests: XCTestCase {
  func testInitialize_v1() {
    let apiVersion: APIVersion = .v1

    XCTAssertEqual(apiVersion.versionIdentifier, "v1")
  }

  func testInitialize_v1beta() {
    let apiVersion: APIVersion = .v1beta

    XCTAssertEqual(apiVersion.versionIdentifier, "v1beta")
  }
}
