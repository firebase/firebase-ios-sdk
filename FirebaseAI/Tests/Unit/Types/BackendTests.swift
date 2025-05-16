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

@testable import FirebaseAI

final class BackendTests: XCTestCase {
  func testVertexAI_defaultLocation() {
    let expectedAPIConfig = APIConfig(
      service: .vertexAI(endpoint: .firebaseProxyProd),
      version: .v1beta
    )

    let backend = Backend.vertexAI()

    XCTAssertEqual(backend.apiConfig, expectedAPIConfig)
    XCTAssertEqual(backend.location, "us-central1")
  }

  func testVertexAI_customLocation() {
    let expectedAPIConfig = APIConfig(
      service: .vertexAI(endpoint: .firebaseProxyProd),
      version: .v1beta
    )
    let customLocation = "europe-west1"

    let backend = Backend.vertexAI(location: customLocation)

    XCTAssertEqual(backend.apiConfig, expectedAPIConfig)
    XCTAssertEqual(backend.location, customLocation)
  }

  func testGoogleAI() {
    let expectedAPIConfig = APIConfig(
      service: .googleAI(endpoint: .firebaseProxyProd),
      version: .v1beta
    )

    let backend = Backend.googleAI()

    XCTAssertEqual(backend.apiConfig, expectedAPIConfig)
    XCTAssertNil(backend.location)
  }
}
