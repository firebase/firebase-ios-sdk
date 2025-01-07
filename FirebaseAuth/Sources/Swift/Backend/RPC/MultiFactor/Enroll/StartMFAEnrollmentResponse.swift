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

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
struct StartMFAEnrollmentResponse: AuthRPCResponse {
  private(set) var phoneSessionInfo: AuthProtoStartMFAPhoneResponseInfo?
  private(set) var totpSessionInfo: AuthProtoStartMFATOTPEnrollmentResponseInfo?

  init(dictionary: [String: AnyHashable]) throws {
    if let data = dictionary["phoneSessionInfo"] as? [String: AnyHashable] {
      phoneSessionInfo = AuthProtoStartMFAPhoneResponseInfo(dictionary: data)
    } else if let data = dictionary["totpSessionInfo"] as? [String: AnyHashable] {
      totpSessionInfo = AuthProtoStartMFATOTPEnrollmentResponseInfo(dictionary: data)
    } else {
      throw AuthErrorUtils.unexpectedResponse(deserializedResponse: dictionary)
    }
  }
}
