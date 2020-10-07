/*
 * Copyright 2019 Google
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import FirebaseCore
import FirebaseMessaging
import XCTest

class FIRMessagingInstanceTest: XCTestCase {
  func testSingleton_worksAfterDelete() {
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct results.
    let options = FirebaseOptions(googleAppID: "1:123:ios:123abc", gcmSenderID: "valid-sender-id")
    options.apiKey = "AIzaSy-ApiKeyWithValidFormat_0123456789"
    options.projectID = "project-id"
    FirebaseApp.configure(options: options)
    let original = Messaging.messaging()

    // Get and delete the default app.
    guard let defaultApp = FirebaseApp.app() else {
      XCTFail("Default app was not configured properly.")
      return
    }

    // The delete API is synchronous, so the default app will be deleted afterwards.
    defaultApp.delete { success in
      XCTAssertTrue(success, "FirebaseApp deletion should be successful")
    }

    XCTAssertNil(FirebaseApp.app(), "The default app should be `nil` at this point.")

    // Re-configure the app to trigger Messaging to re-instantiate.
    FirebaseApp.configure(options: options)

    // Get another instance of Messaging, make sure it's not the same instance.
    let postDelete = Messaging.messaging()
    XCTAssertNotEqual(original, postDelete)
  }
}
