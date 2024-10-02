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

import Foundation

/// Protocol for responses that support Multi-Factor Authentication.
protocol AuthMFAResponse {
  /// An opaque string that functions as proof that the user has successfully passed the first
  /// factor check.
  var mfaPendingCredential: String? { get }

  /// Info on which multi-factor authentication providers are enabled.
  var mfaInfo: [AuthProtoMFAEnrollment]? { get }

  /// MFA is only done when the idToken is nil.
  var idToken: String? { get }
}
