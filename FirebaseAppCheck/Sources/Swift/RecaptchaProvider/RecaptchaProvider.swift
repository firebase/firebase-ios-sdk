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

  // Internal declarations implemented in this file.
  import FirebaseAppCheck.Internal
#endif // SWIFT_PACKAGE

internal import AppCheckCore
internal import FirebaseCoreExtension

// The reCAPTCHA Enterprise provider of App Check Core is available on iOS and visionOS. SwiftPM
// vends it as a separate module; CocoaPods includes it in `AppCheckCore` on iOS.
#if SWIFT_PACKAGE && ((os(iOS) && !targetEnvironment(macCatalyst)) || os(visionOS))
  internal import AppCheckRecaptchaProvider
#endif

/// Implements `FIRRecaptchaProvider`, declared in `FIRRecaptchaProvider.h` and
/// `FIRAppCheckInternal.h`.
@available(iOS 15.0, visionOS 1.0, *)
@available(macOS, unavailable)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
@available(macCatalyst, unavailable)
@objc @implementation extension RecaptchaProvider {
  /// The App Check Core provider that implements reCAPTCHA Enterprise attestation.
  final var recaptchaProvider: AppCheckCoreProvider

  @objc(initWithRecaptchaProvider:)
  init?(recaptchaProvider: Any) {
    // The parameter is `id` in `FIRAppCheckInternal.h`, which doesn't import App Check Core. The
    // header is visible to apps that use CocoaPods or the binary distributions, so don't trap on
    // other objects.
    guard let recaptchaProvider = recaptchaProvider as? AppCheckCoreProvider else {
      return nil
    }
    self.recaptchaProvider = recaptchaProvider
    super.init()
  }

  @objc(initWithApp:siteKey:)
  init?(app: FirebaseApp, siteKey: String) {
    #if (os(iOS) && !targetEnvironment(macCatalyst)) || (SWIFT_PACKAGE && os(visionOS))
      if siteKey.isEmpty {
        let message = "Cannot instantiate `RecaptchaProvider` for app: \(app.name). "
          + "The `siteKey` parameter is missing or empty. "
          + "Please ensure you have provided a valid reCAPTCHA Enterprise site key."
        AppCheckLogger.log(.error, .recaptchaProviderMissingSiteKey, message)
        raiseException(.invalidArgumentException, reason: message)
      }

      let missingOptionsFields = AppCheckValidator.tokenExchangeMissingFields(in: app.options)
      if !missingOptionsFields.isEmpty {
        AppCheckLogger.log(
          .error,
          .recaptchaProviderIncompleteFIROptions,
          "Cannot instantiate `RecaptchaProvider` for app: \(app.name). The following "
            + "`FirebaseOptions` fields are missing: "
            + missingOptionsFields.joined(separator: ", ") + ". "
            + "Please ensure your `GoogleService-Info.plist` is complete or these fields are "
            + "set on `FirebaseOptions` programmatically."
        )
        return nil
      }

      if !RecaptchaProvider.isSupported() {
        let message = "Cannot instantiate `RecaptchaProvider` for app: \(app.name). "
          + "The reCAPTCHA Enterprise SDK is not linked. "
          + "Please ensure you have installed the `FirebaseAppCheck` package along with "
          + "the underlying reCAPTCHA Enterprise dependency. "
          + "See https://cloud.google.com/recaptcha/docs/instrument-ios-apps#prepare-environment "
          + "for details."
        AppCheckLogger.log(.error, .recaptchaProviderMissingRecaptchaEnterpriseSDK, message)
        raiseException(.internalInconsistencyException, reason: message)
      }

      guard let recaptchaProvider = AppCheckRecaptchaProvider(
        siteKey: siteKey,
        resourceName: app.resourceName,
        APIKey: app.options.apiKey ?? "",
        requestHooks: app.appCheckRequestHooks
      ) else {
        return nil
      }
      self.recaptchaProvider = recaptchaProvider
      super.init()
    #else
      return nil
    #endif
  }

  @objc(getTokenWithCompletion:)
  func getToken(completion handler: @escaping @Sendable (AppCheckToken?, Error?) -> Void) {
    recaptchaProvider.getToken(completion: appCheckTokenCompletion(handler))
  }

  @objc(getLimitedUseTokenWithCompletion:)
  func getLimitedUseToken(completion handler: @escaping @Sendable (AppCheckToken?, Error?)
    -> Void) {
    recaptchaProvider.getLimitedUseToken(completion: appCheckTokenCompletion(handler))
  }
}

@available(iOS 15.0, visionOS 1.0, *)
@available(macOS, unavailable)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
@available(macCatalyst, unavailable)
extension RecaptchaProvider {
  /// Returns whether the reCAPTCHA Enterprise SDK is linked.
  static func isSupported() -> Bool {
    #if (os(iOS) && !targetEnvironment(macCatalyst)) || (SWIFT_PACKAGE && os(visionOS))
      return AppCheckRecaptchaProvider.isSupported()
    #else
      return false
    #endif
  }
}

/// Implements `FIRRecaptchaProviderFactory`, declared in `FIRRecaptchaProviderFactory.h`.
@available(iOS 15.0, visionOS 1.0, *)
@available(macOS, unavailable)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
@available(macCatalyst, unavailable)
@objc @implementation extension RecaptchaProviderFactory {
  final let siteKey: String

  @objc(initWithSiteKey:)
  init(siteKey: String) {
    if siteKey.isEmpty {
      raiseException(.invalidArgumentException,
                     reason: "Cannot instantiate RecaptchaProviderFactory. The siteKey parameter "
                       + "is missing or empty.")
    }
    self.siteKey = siteKey
    super.init()
  }

  @objc(createProviderWithApp:)
  func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
    #if (os(iOS) && !targetEnvironment(macCatalyst)) || os(visionOS)
      return RecaptchaProvider(app: app, siteKey: siteKey)
    #else
      return nil
    #endif
  }
}
