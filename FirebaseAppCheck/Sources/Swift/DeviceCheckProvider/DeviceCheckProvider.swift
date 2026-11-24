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

internal import AppCheckCore
internal import FirebaseCoreExtension

/// Implements `FIRDeviceCheckProvider`, declared in `FIRDeviceCheckProvider.h`.
@objc @implementation extension DeviceCheckProvider {
  /// The App Check Core provider that implements DeviceCheck attestation.
  final var deviceCheckProvider: AppCheckCoreProvider

  @objc(initWithApp:)
  init?(app: FirebaseApp) {
    let missingOptionsFields = AppCheckValidator.tokenExchangeMissingFields(in: app.options)
    if !missingOptionsFields.isEmpty {
      AppCheckLogger.log(
        .error,
        .deviceCheckProviderIncompleteFIROptions,
        "Cannot instantiate `FIRDeviceCheckProvider` for app: \(app.name). The following "
          + "`FirebaseOptions` fields are missing: "
          + missingOptionsFields.joined(separator: ", ")
      )
      return nil
    }
    deviceCheckProvider = AppCheckCoreDeviceCheckProvider(serviceName: app.name,
                                                          resourceName: app.resourceName,
                                                          apiKey: app.options.apiKey ?? "",
                                                          requestHooks: app.appCheckRequestHooks)
    super.init()
  }

  @objc(getTokenWithCompletion:)
  func getToken(completion handler: @escaping @Sendable (AppCheckToken?, Error?) -> Void) {
    deviceCheckProvider.getToken(completion: appCheckTokenCompletion(handler))
  }

  @objc(getLimitedUseTokenWithCompletion:)
  func getLimitedUseToken(completion handler: @escaping @Sendable (AppCheckToken?, Error?)
    -> Void) {
    deviceCheckProvider.getLimitedUseToken(completion: appCheckTokenCompletion(handler))
  }
}

/// Implements `FIRDeviceCheckProviderFactory`, declared in `FIRDeviceCheckProviderFactory.h`.
@objc @implementation extension DeviceCheckProviderFactory {
  @objc(createProviderWithApp:)
  func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
    DeviceCheckProvider(app: app)
  }
}
