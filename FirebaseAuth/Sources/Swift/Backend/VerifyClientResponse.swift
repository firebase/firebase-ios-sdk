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

class VerifyClientResponse: AuthRPCResponse {
  required init() {}

  /// Receipt that the APNS token was successfully validated with APNS.
  private(set) var receipt: String?

  /// The date after which delivery of the silent push notification is considered to have failed.
  private(set) var suggestedTimeOutDate: Date?

  func setFields(dictionary: [String: AnyHashable]) throws {
    receipt = dictionary["receipt"] as? String
    let suggestedTimeout = dictionary["suggestedTimeout"]
    if let string = suggestedTimeout as? String,
       let doubleVal = Double(string) {
      suggestedTimeOutDate = Date(timeIntervalSinceNow: doubleVal)
    }
  }
}
