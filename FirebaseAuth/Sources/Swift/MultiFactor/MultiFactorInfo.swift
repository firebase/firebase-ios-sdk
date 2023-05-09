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

  /** @class FIRMultiFactorInfo
   @brief Safe public structure used to represent a second factor entity from a client perspective.
       This class is available on iOS only.
   */
  @objc(FIRMultiFactorInfo) public class MultiFactorInfo: NSObject, NSSecureCoding {
    /**
        @brief The multi-factor enrollment ID.
     */
    @objc(UID) public var uid: String?

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
    @objc public var factorID: String?

    @objc public init(proto: AuthProtoMFAEnrollment) {
      uid = proto.MFAEnrollmentID
      displayName = proto.displayName
      enrollmentDate = proto.enrolledAt
    }

    // MARK: - NSSecureCoding

    public static var supportsSecureCoding: Bool {
      true
    }

    public required init?(coder: NSCoder) {
      uid = coder.decodeObject(of: [NSString.self], forKey: kUIDCodingKey) as? String
      displayName = coder.decodeObject(
        of: [NSString.self],
        forKey: kDisplayNameCodingKey
      ) as? String
      enrollmentDate = coder.decodeObject(
        of: [NSString.self],
        forKey: kEnrollmentDateCodingKey
      ) as? Date
      factorID = coder.decodeObject(of: [NSString.self], forKey: kFactorIDCodingKey) as? String
    }

    public func encode(with coder: NSCoder) {
      coder.encode(uid, forKey: kUIDCodingKey)
      coder.encode(displayName, forKey: kDisplayNameCodingKey)
      coder.encode(enrollmentDate, forKey: kEnrollmentDateCodingKey)
      coder.encode(factorID, forKey: kFactorIDCodingKey)
    }
  }
#endif
