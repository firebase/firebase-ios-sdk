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

import Foundation
import XCTest
@testable import FirebaseCoreLinux

final class FirebaseCoreLinuxTests: XCTestCase {

    override func tearDown() {
        // Cleanup apps
        // Note: delete is async but we invoke nil completion.
        // We might need to ensure cleanup happens synchronously or wait.
        // However, delete removes from _allApps immediately.

        let apps = FirebaseApp.allApps
        for name in apps.keys {
            FirebaseApp.app(name: name)?.delete(completion: nil)
        }
    }

    func testExample() {
        XCTAssertTrue(true)
    }
}
