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

class AuthProtoFinalizeMFATOTPEnrollmentRequestInfo: NSObject, AuthProto {
  required init(dictionary: [String: AnyHashable]) {
    fatalError()
  }

  let sessionInfo: String?
  let verificationCode: String?
  init(sessionInfo: String?, verificationCode: String?) {
    self.sessionInfo = sessionInfo
    self.verificationCode = verificationCode
  }

  var dictionary: [String: AnyHashable] {
    var dict: [String: AnyHashable] = [:]
    if let sessionInfo = sessionInfo {
      dict["sessionInfo"] = sessionInfo
    }
    if let verificationCode = verificationCode {
      dict["verificationCode"] = verificationCode
    }
    return dict
  }
}
