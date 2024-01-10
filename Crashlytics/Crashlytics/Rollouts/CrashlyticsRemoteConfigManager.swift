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

import FirebaseRemoteConfigInterop
import Foundation

protocol CrashlyticsPersistentLog: NSObject {
  func updateRolloutsStateToPersistence(rolloutAssignments: [RolloutAssignment])
}

@objc(FIRCLSRemoteConfigManager)
public class CrashlyticsRemoteConfigManager: NSObject {
  public static let maxRolloutAssignments = 128
  public static let maxParameterValueLength = 256

  var remoteConfig: RemoteConfigInterop
  @objc public private(set) var rolloutAssignment: [RolloutAssignment] = []
  weak var persistenceDelegate: CrashlyticsPersistentLog?

  @objc public init(remoteConfig: RemoteConfigInterop) {
    self.remoteConfig = remoteConfig
  }

  @objc public func updateRolloutsState(rolloutsState: RolloutsState) {
    rolloutAssignment = normalizeRolloutAssignment(assignments: Array(rolloutsState.assignments))
  }

  @objc public func getRolloutAssignmentsEncodedJson() -> String? {
    let contentEncodedRolloutAssignments = rolloutAssignment.map { assignment in
      EncodedRolloutAssignment(assignment: assignment)
    }

    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase
    encoder.outputFormatting = .sortedKeys
    let encodeData = try? encoder.encode(contentEncodedRolloutAssignments)
    if let data = encodeData, let returnString = String(data: data, encoding: .utf8) {
      return returnString
    }

    // TODO(themisw): Hook into core logging functions
    debugPrint("Failed to serialize rollouts", encodeData ?? "nil")
    return nil
  }
}

private extension CrashlyticsRemoteConfigManager {
  func normalizeRolloutAssignment(assignments: [RolloutAssignment]) -> [RolloutAssignment] {
    var validatedAssignments = assignments
    if assignments.count > CrashlyticsRemoteConfigManager.maxRolloutAssignments {
      debugPrint("Rollouts excess the maximum number of assignments can pass to Crashlytics")
      validatedAssignments =
        Array(assignments[..<CrashlyticsRemoteConfigManager.maxRolloutAssignments])
    }

    _ = validatedAssignments.map { assignment in
      if assignment.parameterValue.count > CrashlyticsRemoteConfigManager.maxParameterValueLength {
        debugPrint(
          "Rollouts excess the maximum length of parameter value can pass to Crashlytics",
          assignment.parameterValue
        )
        let upperBound = String.Index(
          utf16Offset: CrashlyticsRemoteConfigManager.maxParameterValueLength,
          in: assignment.parameterValue
        )
        let slicedParameterValue = assignment.parameterValue[..<upperBound]
        assignment.parameterValue = String(slicedParameterValue)
      }
    }

    return validatedAssignments
  }
}
