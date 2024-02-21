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

@objc(FIRCLSPersistenceLog)
public protocol CrashlyticsPersistenceLog {
  func updateRolloutsStateToPersistence(rollouts: Data, reportID: String)
  func debugLog(message: String)
}

@objc(FIRCLSRemoteConfigManager)
public class CrashlyticsRemoteConfigManager: NSObject {
  public static let maxRolloutAssignments = 128
  public static let maxParameterValueLength = 256

  private let lock = NSLock()
  private var _rolloutAssignment: [RolloutAssignment] = []

  var remoteConfig: RemoteConfigInterop
  var persistenceDelegate: CrashlyticsPersistenceLog

  @objc public var rolloutAssignment: [RolloutAssignment] {
    lock.lock()
    defer { lock.unlock() }
    let copy = _rolloutAssignment
    return copy
  }

  @objc public init(remoteConfig: RemoteConfigInterop,
                    persistenceDelegate: CrashlyticsPersistenceLog) {
    self.remoteConfig = remoteConfig
    self.persistenceDelegate = persistenceDelegate
  }

  @objc public func updateRolloutsState(rolloutsState: RolloutsState, reportID: String) {
    lock.lock()
    _rolloutAssignment = normalizeRolloutAssignment(assignments: Array(rolloutsState.assignments))
    lock.unlock()

    // Writring to persistence
    if let rolloutsData =
      getRolloutsStateEncodedJsonData() {
      persistenceDelegate.updateRolloutsStateToPersistence(
        rollouts: rolloutsData,
        reportID: reportID
      )
    }
  }

  /// Return string format: [{RolloutAssignment1}, {RolloutAssignment2}, {RolloutAssignment3}...]
  /// This will get inserted into each clsrcord for non-fatal events.
  /// Return a string type because later `FIRCLSFileWriteStringUnquoted` takes string as input
  @objc public func getRolloutAssignmentsEncodedJsonString() -> String? {
    let encodeData = getRolloutAssignmentsEncodedJsonData()
    if let data = encodeData {
      return String(data: data, encoding: .utf8)
    }

    let debugInfo = encodeData?.debugDescription ?? "nil"
    persistenceDelegate.debugLog(message: String(
      format: "Failed to serialize rollouts: %@",
      arguments: [debugInfo]
    ))

    return nil
  }
}

private extension CrashlyticsRemoteConfigManager {
  func normalizeRolloutAssignment(assignments: [RolloutAssignment]) -> [RolloutAssignment] {
    var validatedAssignments = assignments
    if assignments.count > CrashlyticsRemoteConfigManager.maxRolloutAssignments {
      persistenceDelegate
        .debugLog(
          message: "Rollouts excess the maximum number of assignments can pass to Crashlytics"
        )
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

  // Helper for later convert Data to String. Because `FIRCLSFileWriteStringUnquoted` takes string
  // as input
  func getRolloutAssignmentsEncodedJsonData() -> Data? {
    let contentEncodedRolloutAssignments = rolloutAssignment.map { assignment in
      EncodedRolloutAssignment(assignment: assignment)
    }

    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase
    encoder.outputFormatting = .sortedKeys
    let encodeData = try? encoder.encode(contentEncodedRolloutAssignments)
    return encodeData
  }

  /// Return string format: {"rollouts": [{RolloutAssignment1}, {RolloutAssignment2},
  /// {RolloutAssignment3}...]}
  /// This will get stored in the separate rollouts.clsrecord
  /// Return a data  type because later `[NSFileHandler writeData:]` takes data as input
  func getRolloutsStateEncodedJsonData() -> Data? {
    let contentEncodedRolloutAssignments = rolloutAssignment.map { assignment in
      EncodedRolloutAssignment(assignment: assignment)
    }

    let state = EncodedRolloutsState(assignments: contentEncodedRolloutAssignments)
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase
    let encodeData = try? encoder.encode(state)
    return encodeData
  }
}
