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

#if canImport(Testing)
  import Foundation
  import Testing

  @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  extension Trait where Self == Testing.ConditionTrait {
    /// Requires physical hardware. Skips in the Simulator.
    static var requirePhysicalDevice: Self {
      .enabled(
        if: AppCheckTestEnvironment.isPhysicalDevice,
        "Requires a physical device; App Attest and DeviceCheck are unavailable in the Simulator"
      )
    }

    /// Requires a `GoogleService-Info.plist` and a debug token for live
    /// backend exchange.
    static var requireLiveCredentials: Self {
      .enabled(
        if: AppCheckTestEnvironment.hasLiveCredentials,
        "Requires GoogleService-Info.plist and the AppCheckDebugToken environment variable"
      )
    }

    /// Requires a debug token registered in the Firebase console.
    static var requireDebugToken: Self {
      .enabled(
        if: AppCheckTestEnvironment.hasDebugToken,
        "Requires the AppCheckDebugToken environment variable"
      )
    }

    /// Requires a valid DeviceCheck private key registered with the App Check
    /// backend.
    ///
    /// Opt-in via `APP_CHECK_DEVICE_CHECK_READY`. A revoked key yields a
    /// backend rejection that mimics an SDK regression, so these stay off
    /// until the key is confirmed live.
    static var requireDeviceCheckBackend: Self {
      .enabled(
        if: AppCheckTestEnvironment.hasDeviceCheckBackend,
        "Requires a live DeviceCheck key; set APP_CHECK_DEVICE_CHECK_READY once uploaded"
      )
    }

    /// Requires a reCAPTCHA Enterprise site key. iOS and visionOS only.
    static var requireRecaptcha: Self {
      .enabled(
        if: AppCheckTestEnvironment.recaptchaSiteKey != nil,
        "Requires the RECAPTCHA_SITE_KEY environment variable"
      )
    }
  }
#endif // canImport(Testing)
