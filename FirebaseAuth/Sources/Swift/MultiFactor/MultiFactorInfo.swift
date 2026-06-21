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

// TODO(Swift 6 Breaking): Make checked Sendable.

#if os(iOS) || os(macOS)
  extension MultiFactorInfo: NSSecureCoding {}

  /// Safe public structure used to represent a second factor entity from a client perspective.
  ///
  /// This class is available on iOS and macOS.
  @objc(FIRMultiFactorInfo) open class MultiFactorInfo: NSObject, @unchecked Sendable {
    /// The multi-factor enrollment ID.
    @objc(UID) public let uid: String

    /// The user friendly name of the current second factor.
    @objc public let displayName: String?

    /// The second factor enrollment date.
    @objc public let enrollmentDate: Date

    /// The identifier of the second factor.
    @objc public let factorID: String

    init(proto: AuthProtoMFAEnrollment, factorID: String) {
      guard let uid = proto.mfaEnrollmentID else {
        fatalError("Auth Internal Error: Failed to initialize MFA: missing enrollment ID")
      }
      self.uid = uid
      self.factorID = factorID
      displayName = proto.displayName
      enrollmentDate = proto.enrolledAt ?? Date()
    }

    // MARK: NSSecureCoding

    private let kUIDCodingKey = "uid"
    private let kDisplayNameCodingKey = "displayName"
    private let kEnrollmentDateCodingKey = "enrollmentDate"
    private let kFactorIDCodingKey = "factorID"

    public class var supportsSecureCoding: Bool { return true }

    public func encode(with coder: NSCoder) {
      coder.encode(uid, forKey: kUIDCodingKey)
      coder.encode(displayName, forKey: kDisplayNameCodingKey)
      coder.encode(enrollmentDate, forKey: kEnrollmentDateCodingKey)
      coder.encode(factorID, forKey: kFactorIDCodingKey)
    }

    public required init?(coder: NSCoder) {
      guard let uid = coder.decodeObject(of: [NSString.self], forKey: kUIDCodingKey) as? String,
            let factorID = coder.decodeObject(of: [NSString.self],
                                              forKey: kFactorIDCodingKey) as? String,
            let enrollmentDate = coder.decodeObject(of: [NSDate.self],
                                                    forKey: kEnrollmentDateCodingKey) as? Date
      else {
        return nil
      }
      self.uid = uid
      self.factorID = factorID
      self.enrollmentDate = enrollmentDate
      displayName = coder.decodeObject(
        of: [NSString.self],
        forKey: kDisplayNameCodingKey
      ) as? String
    }
  }
#endif
