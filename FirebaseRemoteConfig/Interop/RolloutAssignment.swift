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

@objc(FIRRolloutAssignment)
public class RolloutAssignment: NSObject {
  @objc public var rolloutId: String
  @objc public var variantId: String
  @objc public var templateVersion: Int64
  @objc public var parameterKey: String
  @objc public var parameterValue: String

  @objc public init(rolloutId: String, variantId: String, templateVersion: Int64,
                    parameterKey: String,
                    parameterValue: String) {
    self.rolloutId = rolloutId
    self.variantId = variantId
    self.templateVersion = templateVersion
    self.parameterKey = parameterKey
    self.parameterValue = parameterValue
    super.init()
  }
}

@objc(FIRRolloutsState)
public class RolloutsState: NSObject {
  @objc public var assignments: Set<RolloutAssignment> = Set()

  @objc public init(assignmentList: [RolloutAssignment]) {
    for assignment in assignmentList {
      assignments.insert(assignment)
    }
    super.init()
  }
}
