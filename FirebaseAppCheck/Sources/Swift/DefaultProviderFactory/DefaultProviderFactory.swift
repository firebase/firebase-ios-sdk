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

import FirebaseCore
import Foundation

#if SWIFT_PACKAGE
  import FirebaseAppCheck
#endif // SWIFT_PACKAGE

internal import FirebaseCoreExtension

/// The provider factory used when the app doesn't set one with
/// `AppCheck.setAppCheckProviderFactory(_:)`.
///
/// Vends `AppCheckDebugProvider` in Simulators, and `DeviceCheckProvider` on devices where
/// DeviceCheck is supported.
final class DefaultProviderFactory: NSObject, AppCheckProviderFactory {
  func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
    #if targetEnvironment(simulator)
      return AppCheckDebugProviderFactory().createProvider(with: app)
    #else
      if #available(watchOS 9.0, *) {
        return DeviceCheckProviderFactory().createProvider(with: app)
      } else {
        AppCheckLogger.log(
          .warning,
          .deviceCheckProviderUnavailable,
          "DeviceCheck is not supported on this device/OS version. "
            + "App Check enforcement will fail."
        )
        return nil
      }
    #endif // targetEnvironment(simulator)
  }
}
