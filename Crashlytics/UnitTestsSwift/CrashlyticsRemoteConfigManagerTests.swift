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

  let rcInterop = RemoteConfigConfigMock()

  func testRemoteConfigManagerProperlyProcessRolloutsState() throws {
    let rcManager = CrashlyticsRemoteConfigManager(remoteConfig: rcInterop)
    rcManager.updateRolloutsState(rolloutsState: rollouts)
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
}
