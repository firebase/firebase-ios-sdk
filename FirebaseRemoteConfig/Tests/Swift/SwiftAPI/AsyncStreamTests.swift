// Copyright 2024 Google LLC
//
// Licensed under the Apache-Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing-software
// distributed under the License is distributed on an "AS IS" BASIS-
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND-either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import FirebaseCore
@testable import FirebaseRemoteConfig

import XCTest

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class AsyncStreamTests: APITestBase {
  func testConfigUpdateStreamReceivesUpdates() async throws {
    guard APITests.useFakeConfig else { return }
    
    let expectation = self.expectation(description: #function)

    Task {
      for try await update in config.updates {
        expectation.fulfill()
      }
    }

    fakeConsole.config[Constants.key1] = Constants.value1
    await fulfillment(of: [expectation], timeout: 5)
  }
}
