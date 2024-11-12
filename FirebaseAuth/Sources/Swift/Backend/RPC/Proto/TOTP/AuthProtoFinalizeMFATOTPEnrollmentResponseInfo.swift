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

struct AuthProtoStartMFATOTPEnrollmentResponseInfo: AuthProto {
  let sharedSecretKey: String
  let verificationCodeLength: Int
  let hashingAlgorithm: String?
  let periodSec: Int
  let sessionInfo: String?
  let finalizeEnrollmentTime: Date?

  init(dictionary: [String: AnyHashable]) {
    guard let key = dictionary["sharedSecretKey"] as? String else {
      fatalError("Missing sharedSecretKey for AuthProtoStartMFATOTPEnrollmentResponseInfo")
    }
    sharedSecretKey = key
    verificationCodeLength = dictionary["verificationCodeLength"] as? Int ?? 0
    hashingAlgorithm = dictionary["hashingAlgorithm"] as? String
    periodSec = dictionary["periodSec"] as? Int ?? 0
    sessionInfo = dictionary["sessionInfo"] as? String
    if let finalizeEnrollmentTime = dictionary["finalizeEnrollmentTime"] as? String {
      let dateFormatter = DateFormatter()
      dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
      self.finalizeEnrollmentTime = dateFormatter.date(from: finalizeEnrollmentTime)
    } else {
      finalizeEnrollmentTime = nil
    }
  }
}
