// Copyright 2023 Google LLC
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

@testable import FirebaseAuth
import FirebaseCore
import UIKit

/// Manage FirebaseApp instances for the Sample app

class AppManager {
  static let shared = AppManager()

  private var defaultApp: FirebaseApp
  private var otherApp: FirebaseApp
  var app: FirebaseApp

  // TenantConfig for regionalized Auth
  private let tenantConfig = TenantConfig(tenantId: "Foo-e2e-tenant-007", location: "global")

  // Cached Auth instances
  private var defaultAppAuth: Auth
  private var otherAppAuth: Auth
  private var regionalAuthInstance: Auth

  func auth() -> Auth {
    /// Always return the specific regional instance
    return regionalAuthInstance
  }

  private init() {
    defaultApp = FirebaseApp.app()!
    defaultAppAuth = Auth.auth(app: defaultApp)
    guard let path = Bundle.main.path(forResource: "GoogleService-Info_multi", ofType: "plist"),
          let options = FirebaseOptions(contentsOfFile: path) else {
      fatalError("GoogleService-Info_multi.plist must be added to the project")
    }
    if FirebaseApp.app(name: "OtherApp") == nil {
      FirebaseApp.configure(name: "OtherApp", options: options)
    }
    guard let other = FirebaseApp.app(name: "OtherApp") else {
      fatalError("Failed to find OtherApp")
    }
    otherApp = other
    otherAppAuth = Auth.auth(app: otherApp)
    regionalAuthInstance = Auth.auth(app: otherApp, tenantConfig: tenantConfig)
    print("AppManager init: regionalAuthInstance created: \(regionalAuthInstance)")
    app = defaultApp
  }

  func toggle() {
    if app == defaultApp {
      app = otherApp
    } else {
      app = defaultApp
    }
  }

  /// Function to get the standard Auth instance based on the current 'app'
  func standardAuth() -> Auth {
    if app == defaultApp {
      return defaultAppAuth
    } else {
      return otherAppAuth
    }
  }
}
