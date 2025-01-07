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

import FirebaseAppCheck
import FirebaseCore
import Foundation

/// An `AppCheckProviderFactory` for the Test App.
///
/// Defaults to the `AppCheckDebugProvider` unless the `FirebaseApp` `name` contains
/// ``notConfiguredName``, in which case App Check is not configured; this facilitates integration
/// testing of App Check failure cases.
public class TestAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
  /// The name, or a substring of the name, of Firebase apps where App Check is not configured.
  public static let notConfiguredName = "app-check-not-configured"

  /// Returns the `AppCheckDebugProvider` unless  `app.name` contains ``notConfiguredName``.
  public func createProvider(with app: FirebaseApp) -> (any AppCheckProvider)? {
    if app.name.contains(TestAppCheckProviderFactory.notConfiguredName) {
      return nil
    }

    return AppCheckDebugProvider(app: app)
  }
}
