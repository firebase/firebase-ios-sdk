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

import Foundation

/// App Check Core's error domain.
///
/// Providers called directly (`AppAttestProvider(app:)?.getToken()`) hand back
/// the core error untranslated. Only errors that pass through
/// `AppCheck.token(forcingRefresh:)` are mapped into `AppCheckErrorDomain`.
let appCheckCoreErrorDomain = "com.google.app_check_core"

/// `GACAppCheckErrorCodeUnsupported` / `AppCheckCoreErrorCode.unsupported`.
let appCheckCoreUnsupportedCode = 4

/// Whether `error` is App Check Core's "unsupported attestation provider"
/// error, which App Attest and DeviceCheck return in the Simulator.
///
/// Pinned to the literal domain and code rather than "any App Check error" so
/// that a network failure, a backend rejection, or a change in how
/// unsupported is reported cannot satisfy it.
func isUnsupportedProviderError(_ error: any Error) -> Bool {
  let nsError = error as NSError
  return nsError.domain == appCheckCoreErrorDomain
    && nsError.code == appCheckCoreUnsupportedCode
}

/// The HTTP status code carried by a backend rejection, or `nil` if `error`
/// is not one.
///
/// Read from `NSLocalizedFailureReasonErrorKey`, the only place the status is
/// observable to callers in both v11 and v12:
///
/// - In v11, `GACAppCheckHTTPError` (which exposes the response) was a private
///   header, so callers only ever had the generic `NSError` surface.
/// - In v12, `AppCheckCoreHTTPError` is public, but it does not survive the
///   completion-handler hop: callers receive a `__SwiftNativeNSError` box with
///   the same domain, code, and `userInfo`, and no `httpResponse`.
///
/// Both versions format the reason as "... HTTP status code: <n> ...".
func httpStatusCode(of error: any Error) -> Int? {
  let nsError = error as NSError
  guard let reason = nsError.userInfo[NSLocalizedFailureReasonErrorKey] as? String,
        let range = reason.range(of: #"HTTP status code: (\d+)"#, options: .regularExpression)
  else {
    return nil
  }
  return Int(reason[range].split(separator: " ").last ?? "")
}
