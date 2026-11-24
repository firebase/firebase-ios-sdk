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

/// Implements `FIRAppAttestProvider`, declared in `FIRAppAttestProvider.h`.
@available(macOS 11.3, watchOS 9.0, *)
@objc @implementation extension AppAttestProvider {
  /// The App Check Core provider that implements App Attest attestation.
  final var appAttestProvider: AppCheckCoreProvider

  @objc(initWithApp:)
  init?(app: FirebaseApp) {
    appAttestProvider = AppCheckCoreAppAttestProvider(serviceName: app.name,
                                                      resourceName: app.resourceName,
                                                      baseURL: nil,
                                                      apiKey: app.options.apiKey,
                                                      keychainAccessGroup: app.options.appGroupID,
                                                      requestHooks: app.appCheckRequestHooks)
    super.init()
  }

  @objc(getTokenWithCompletion:)
  func getToken(completion handler: @escaping @Sendable (AppCheckToken?, Error?) -> Void) {
    appAttestProvider.getToken(completion: appCheckTokenCompletion(handler))
  }

  @objc(getLimitedUseTokenWithCompletion:)
  func getLimitedUseToken(completion handler: @escaping @Sendable (AppCheckToken?, Error?)
    -> Void) {
    appAttestProvider.getLimitedUseToken(completion: appCheckTokenCompletion(handler))
  }
}

/// Implements `FIRAppAttestProviderFactory`, declared in `FIRAppAttestProviderFactory.h`.
@available(macOS 11.3, watchOS 9.0, *)
@objc @implementation extension AppAttestProviderFactory {
  @objc(createProviderWithApp:)
  func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
    AppAttestProvider(app: app)
  }
}
