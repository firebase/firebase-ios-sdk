// Copyright 2022 Google LLC
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

@testable import FirebaseAppDistribution
import XCTest

class AppDistributionAPITests: XCTestCase {
  @available(iOS 13.0.0, *)
  func asyncAPIs() async throws {
    let distro = AppDistribution.appDistribution()

    // Release should be optional if there are no new releases.
    let _: AppDistributionRelease? = try await distro.checkForUpdate()
    try await distro.signInTester()
  }
}
