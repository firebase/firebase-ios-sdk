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

@objc(FIRMultiFactorInfo) public class MultiFactorInfo: NSObject, NSSecureCoding {

    @objc public var UID: String?

 /**
    @brief The user friendly name of the current second factor.
 */
    @objc public var displayName: String?

 /**
    @brief The second factor enrollment date.
 */
    @objc public var enrollmentDate: Date?

 /**
    @brief The identifier of the second factor.
 */
    @objc internal var factorID: String?

    @objc public init(proto: AuthProtoMFAEnrollment) {
        self.UID = proto.MFAEnrollmentID
        self.displayName = proto.displayName
        self.enrollmentDate = proto.enrolledAt
    }

    // MARK: - NSSecureCoding

    public static var supportsSecureCoding: Bool {
        true
    }

    public required init?(coder: NSCoder) {
        self.UID = coder.decodeObject(of: [NSString.self], forKey: kUIDCodingKey) as? String
        self.displayName = coder.decodeObject(of: [NSString.self], forKey: kDisplayNameCodingKey) as? String
        self.enrollmentDate = coder.decodeObject(of: [NSString.self], forKey: kEnrollmentDateCodingKey) as? Date
        self.factorID = coder.decodeObject(of: [NSString.self], forKey: kFactorIDCodingKey) as? String
    }

    public func encode(with coder: NSCoder) {
        coder.encode(UID, forKey: kUIDCodingKey)
        coder.encode(displayName, forKey: kDisplayNameCodingKey)
        coder.encode(enrollmentDate, forKey: kEnrollmentDateCodingKey)
        coder.encode(factorID, forKey: kFactorIDCodingKey)
    }
}
#endif
