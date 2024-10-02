// Copyright 2024 Google LLC
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

import FirebaseRemoteConfigInterop
import Foundation

@objc(FIRCLSEncodedRolloutsState)
class EncodedRolloutsState: NSObject, Codable {
  @objc public private(set) var rollouts: [EncodedRolloutAssignment]

  @objc public init(assignments: [EncodedRolloutAssignment]) {
    rollouts = assignments
    super.init()
  }
}

@objc(FIRCLSEncodedRolloutAssignment)
class EncodedRolloutAssignment: NSObject, Codable {
  @objc public private(set) var rolloutId: String
  @objc public private(set) var variantId: String
  @objc public private(set) var templateVersion: Int64
  @objc public private(set) var parameterKey: String
  @objc public private(set) var parameterValue: String

  public init(assignment: RolloutAssignment) {
    rolloutId = FileUtility.stringToHexConverter(for: assignment.rolloutId)
    variantId = FileUtility.stringToHexConverter(for: assignment.variantId)
    templateVersion = assignment.templateVersion
    parameterKey = FileUtility.stringToHexConverter(for: assignment.parameterKey)
    parameterValue = FileUtility.stringToHexConverter(for: assignment.parameterValue)
    super.init()
  }
}
