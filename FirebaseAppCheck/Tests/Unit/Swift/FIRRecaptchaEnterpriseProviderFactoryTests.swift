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

@testable import FirebaseAppCheck
import FirebaseCore
import XCTest

final class FIRRecaptchaEnterpriseProviderFactoryTests: XCTestCase {
  func testCreateProviderWithApp() throws {
    let options = FirebaseOptions(googleAppID: "app_id", gcmSenderID: "sender_id")
    options.apiKey = "api_key"
    options.projectID = "project_id"

    let app = FirebaseApp(instanceWithName: "testCreateProviderWithApp", options: options)
    app.isDataCollectionDefaultEnabled = false

    let siteKey = "test_site_key"
    let factory = AppCheckRecaptchaEnterpriseProviderFactory(siteKey: siteKey)

    let createdProvider = factory.createProvider(with: app)

    XCTAssertTrue(createdProvider is RecaptchaEnterpriseProvider)
  }
}
