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
#if SWIFT_PACKAGE
  @testable import FirebaseCrashlyticsSwift
#else
  @testable import FirebaseCrashlytics
#endif
import FirebaseRemoteConfigInterop
import XCTest

class RemoteConfigConfigMock: RemoteConfigInterop {
  func registerRolloutsStateSubscriber(_ subscriber: FirebaseRemoteConfigInterop
    .RolloutsStateSubscriber,
    for namespace: String) {}
}

class PersistenceManagerMock: CrashlyticsPersistenceLog {
  func updateRolloutsStateToPersistence(rollouts: Data, reportID: String) {}
  func debugLog(message: String) {}
}

final class CrashlyticsRemoteConfigManagerTests: XCTestCase {
  let rollouts: RolloutsState = {
    let assignment1 = RolloutAssignment(
      rolloutId: "rollout_1",
      variantId: "control",
      templateVersion: 1,
      parameterKey: "my_feature",
      parameterValue: "false"
    )
    let assignment2 = RolloutAssignment(
      rolloutId: "rollout_2",
      variantId: "enabled",
      templateVersion: 1,
      parameterKey: "themis_big_feature",
      parameterValue: "1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111"
    )
    let rollouts = RolloutsState(assignmentList: [assignment1, assignment2])
    return rollouts
  }()

  let singleRollout: RolloutsState = {
    let assignment1 = RolloutAssignment(
      rolloutId: "rollout_1",
      variantId: "control",
      templateVersion: 1,
      parameterKey: "my_feature",
      parameterValue: "这是themis的测试数据，输入中文" // check unicode
    )
    let rollouts = RolloutsState(assignmentList: [assignment1])
    return rollouts
  }()

  let rcInterop = RemoteConfigConfigMock()

  func testRemoteConfigManagerProperlyProcessRolloutsState() throws {
    let rcManager = CrashlyticsRemoteConfigManager(
      remoteConfig: rcInterop,
      persistenceDelegate: PersistenceManagerMock()
    )
    rcManager.updateRolloutsState(rolloutsState: rollouts, reportID: "12R")
    XCTAssertEqual(rcManager.rolloutAssignment.count, 2)

    for assignment in rollouts.assignments {
      if assignment.parameterKey == "themis_big_feature" {
        XCTAssertEqual(
          assignment.parameterValue.count,
          CrashlyticsRemoteConfigManager.maxParameterValueLength
        )
      }
    }
  }

  func testRemoteConfigManagerGenerateEncodedRolloutAssignmentsJson() throws {
    let expectedString =
      "[{\"parameter_key\":\"6d795f66656174757265\",\"parameter_value\":\"e8bf99e698af7468656d6973e79a84e6b58be8af95e695b0e68daeefbc8ce8be93e585a5e4b8ade69687\",\"rollout_id\":\"726f6c6c6f75745f31\",\"template_version\":1,\"variant_id\":\"636f6e74726f6c\"}]"

    let rcManager = CrashlyticsRemoteConfigManager(
      remoteConfig: rcInterop,
      persistenceDelegate: PersistenceManagerMock()
    )
    rcManager.updateRolloutsState(rolloutsState: singleRollout, reportID: "456")

    let string = rcManager.getRolloutAssignmentsEncodedJsonString()
    XCTAssertEqual(string, expectedString)
  }

  func testMultiThreadsUpdateRolloutAssignments() throws {
    let rcManager = CrashlyticsRemoteConfigManager(
      remoteConfig: rcInterop,
      persistenceDelegate: PersistenceManagerMock()
    )
    DispatchQueue.main.async { [weak self] in
      if let singleRollout = self?.singleRollout {
        rcManager.updateRolloutsState(rolloutsState: singleRollout, reportID: "456")
        XCTAssertEqual(rcManager.rolloutAssignment.count, 1)
      }
    }

    DispatchQueue.main.async { [weak self] in
      if let rollouts = self?.rollouts {
        rcManager.updateRolloutsState(rolloutsState: rollouts, reportID: "456")
        XCTAssertEqual(rcManager.rolloutAssignment.count, 2)
      }
    }
  }

  func testMultiThreadsReadAndWriteRolloutAssignments() throws {
    let rcManager = CrashlyticsRemoteConfigManager(
      remoteConfig: rcInterop,
      persistenceDelegate: PersistenceManagerMock()
    )
    rcManager.updateRolloutsState(rolloutsState: singleRollout, reportID: "456")

    DispatchQueue.main.async { [weak self] in
      if let rollouts = self?.rollouts {
        let oldAssignments = rcManager.rolloutAssignment
        rcManager.updateRolloutsState(rolloutsState: rollouts, reportID: "456")
        XCTAssertEqual(rcManager.rolloutAssignment.count, 2)
        XCTAssertEqual(oldAssignments.count, 1)
      }
    }
    XCTAssertEqual(rcManager.rolloutAssignment.count, 1)
  }
}
