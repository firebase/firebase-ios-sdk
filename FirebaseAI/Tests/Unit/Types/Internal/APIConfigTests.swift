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
final class APIConfigTests: XCTestCase {
  func testInitialize_vertexAI_prod_v1() {
    let apiConfig = APIConfig(service: .vertexAI(endpoint: .firebaseVertexAIProd), version: .v1)

    XCTAssertEqual(apiConfig.service.endpoint.rawValue, "https://firebasevertexai.googleapis.com")
    XCTAssertEqual(apiConfig.version.rawValue, "v1")
  }

  func testInitialize_vertexAI_prod_v1beta() {
    let apiConfig = APIConfig(service: .vertexAI(endpoint: .firebaseVertexAIProd), version: .v1beta)

    XCTAssertEqual(apiConfig.service.endpoint.rawValue, "https://firebasevertexai.googleapis.com")
    XCTAssertEqual(apiConfig.version.rawValue, "v1beta")
  }

  func testInitialize_vertexAI_staging_v1() {
    let apiConfig = APIConfig(service: .vertexAI(endpoint: .firebaseVertexAIStaging), version: .v1)

    XCTAssertEqual(
      apiConfig.service.endpoint.rawValue, "https://staging-firebasevertexai.sandbox.googleapis.com"
    )
    XCTAssertEqual(apiConfig.version.rawValue, "v1")
  }

  func testInitialize_vertexAI_staging_v1beta() {
    let apiConfig = APIConfig(
      service: .vertexAI(endpoint: .firebaseVertexAIStaging),
      version: .v1beta
    )

    XCTAssertEqual(
      apiConfig.service.endpoint.rawValue, "https://staging-firebasevertexai.sandbox.googleapis.com"
    )
    XCTAssertEqual(apiConfig.version.rawValue, "v1beta")
  }

  func testInitialize_developer_staging_v1beta() {
    let apiConfig = APIConfig(
      service: .developer(endpoint: .firebaseVertexAIStaging), version: .v1beta
    )

    XCTAssertEqual(
      apiConfig.service.endpoint.rawValue, "https://staging-firebasevertexai.sandbox.googleapis.com"
    )
    XCTAssertEqual(apiConfig.version.rawValue, "v1beta")
  }

  func testInitialize_developer_generativeLanguage_v1beta() {
    let apiConfig = APIConfig(service: .developer(endpoint: .generativeLanguage), version: .v1beta)

    XCTAssertEqual(apiConfig.service.endpoint.rawValue, "https://generativelanguage.googleapis.com")
    XCTAssertEqual(apiConfig.version.rawValue, "v1beta")
  }
}
