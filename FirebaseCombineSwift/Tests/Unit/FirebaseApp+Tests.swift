// Copyright 2020 Google LLC
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
import FirebaseCore

extension FirebaseApp {
  static func appOptions() -> FirebaseOptions {
    let options = FirebaseOptions(
      googleAppID: Credentials.googleAppID,
      gcmSenderID: Credentials.gcmSenderID
    )
    options.apiKey = Credentials.apiKey
    options.clientID = Credentials.clientID
    options.bundleID = Credentials.bundleID
    options.projectID = Credentials.projectID
    options.storageBucket = Credentials.bucket
    return options
  }

  static func configureForTests() {
    configure(options: appOptions())
  }

  static func appForAuthUnitTestsWithName(name: String) -> FirebaseApp {
    return FirebaseApp(instanceWithName: name, options: appOptions())
  }

  static func appForStorageUnitTestsWithName(name: String) -> FirebaseApp {
    let app = FirebaseApp(instanceWithName: name, options: appOptions())
    let registrants = NSMutableSet(object: FIRStorageComponent.self)
    app.container = FirebaseComponentContainer(app: app, registrants: registrants)
    return app
  }
}
