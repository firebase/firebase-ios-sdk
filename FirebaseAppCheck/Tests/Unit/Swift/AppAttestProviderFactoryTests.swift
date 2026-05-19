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

import FirebaseAppCheck
internal import FirebaseCoreExtension
import XCTest

@available(iOS 14.0, macOS 11.3, macCatalyst 14.5, tvOS 15.0, watchOS 9.0, *)
final class AppAttestProviderFactoryTests: XCTestCase {
  func testCreateProviderWithApp() async throws {
    let options = FirebaseOptions(googleAppID: "app_id", gcmSenderID: "sender_id")
    options.apiKey = "api_key"
    options.projectID = "project_id"
    let appName = "test_app_name"
    let app = FirebaseApp(instanceWithName: appName, options: options)
    // The following disables automatic token refresh, which could interfere with tests.
    app.isDataCollectionDefaultEnabled = false

    let factory = AppAttestProviderFactory()

    let provider = try XCTUnwrap(factory.createProvider(with: app))
    XCTAssertTrue(provider.isKind(of: AppAttestProvider.self))
    await app.delete()
  }
}
