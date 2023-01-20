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

#if os(iOS)
private let kUIDCodingKey = "uid"

private let kDisplayNameCodingKey = "displayName"

private let kEnrollmentDateCodingKey = "enrollmentDate"

private let kFactorIDCodingKey = "factorID"

@objc(FIRMultiFactorSession) public class MultiFactorSession: NSObject {

    // XXX TODO SHOULD BE INTERNAL
    @objc public var IDToken: String?

    // XXX TODO SHOULD BE INTERNAL
    @objc public var MFAPendingCredential: String?

    // XXX TODO SHOULD BE INTERNAL
    @objc public var multiFactorInfo: MultiFactorInfo?

    @objc public static var sessionForCurrentUser: MultiFactorSession {
        let currentUser = Auth.auth().currentUser
        let idToken = currentUser?.rawAccessToken
        return .init(IDToken: idToken)
    }

    @objc public init(IDToken: String?) {
        self.IDToken = IDToken
    }
}

#endif
