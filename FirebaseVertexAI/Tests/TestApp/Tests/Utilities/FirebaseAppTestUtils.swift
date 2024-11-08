// Copyright 2024 Google LLC
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

import FirebaseCore

extension FirebaseApp {
  /// Configures another `FirebaseApp` with the specified `name` and the same `FirebaseOptions`.
  func namedCopy(name: String) throws -> FirebaseApp {
    FirebaseApp.configure(name: name, options: options)
    guard let app = FirebaseApp.app(name: name) else {
      throw AppNotFound(name: name)
    }
    return app
  }

  /// Configures an app with the specified `name` and the same `FirebaseOptions` as the default app.
  static func defaultNamedCopy(name: String) throws -> FirebaseApp {
    guard FirebaseApp.isDefaultAppConfigured(), let defaultApp = FirebaseApp.app() else {
      throw DefaultAppNotConfigured()
    }
    return try defaultApp.namedCopy(name: name)
  }

  struct AppNotFound: Error {
    let name: String
  }

  struct DefaultAppNotConfigured: Error {}
}
